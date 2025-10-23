const functions = require('firebase-functions');
const admin = require('firebase-admin');
const fetch = require('node-fetch');

// Use existing admin instance if already initialized
let db;
try {
  db = admin.firestore();
} catch (e) {
  // Admin already initialized in index.js
  db = admin.firestore();
}

// OpenAI key helper
function getOpenAIKey() {
  try {
    const cfg = functions.config();
    if (cfg && cfg.openai && cfg.openai.key) return cfg.openai.key;
  } catch (_) {}
  return process.env.OPENAI_API_KEY;
}

// Cache helpers for English translations
function englishTranslationHash(word) {
  const crypto = require('crypto');
  return crypto.createHash('md5').update(word.trim().toLowerCase()).digest('hex');
}

async function checkEnglishTranslationCache(englishWord) {
  const hash = englishTranslationHash(englishWord);
  const doc = await db.collection('englishTranslationCache').doc(hash).get();
  if (!doc.exists) return null;
  
  const data = doc.data();
  
  // Check TTL (7 days)
  const ttlMs = 7 * 24 * 60 * 60 * 1000;
  const now = Date.now();
  const firstCached = data.metadata?.firstCached?.toMillis?.() || 0;
  const age = now - firstCached;
  
  if (age > ttlMs) {
    console.log(`Cache expired for ${englishWord}, age: ${age}ms`);
    return null;
  }
  
  // Update hit count
  await doc.ref.update({
    'metadata.hitCount': admin.firestore.FieldValue.increment(1),
    'metadata.lastUsed': admin.firestore.FieldValue.serverTimestamp()
  });
  
  return data;
}

async function storeEnglishTranslationCache(englishWord, suggestions) {
  const hash = englishTranslationHash(englishWord);
  const ref = db.collection('englishTranslationCache').doc(hash);
  await ref.set({
    englishWord,
    suggestions,
    metadata: {
      hitCount: 0,
      firstCached: admin.firestore.FieldValue.serverTimestamp(),
      lastUsed: admin.firestore.FieldValue.serverTimestamp(),
      ttl: 7 * 24 * 60 * 60 * 1000, // 7 days
      model: 'gpt-4o-mini'
    }
  }, { merge: true });
}

// Get conversation context (last N messages)
async function getConversationContext(conversationId, limit = 10) {
  try {
    const q = await db.collection('messages')
      .where('conversationId', '==', conversationId)
      .orderBy('timestamp', 'desc')
      .limit(limit)
      .get();
    return q.docs.map(d => d.data());
  } catch (error) {
    console.error('Error fetching context:', error);
    return [];
  }
}

// Build context string for RAG
function buildContextString(context = []) {
  if (context.length === 0) return 'No previous context available.';
  
  return context.slice(0, 10)
    .map(m => {
      const text = String(m.text || '');
      return `- ${text}`;
    })
    .join('\n');
}

// Offensive/inappropriate words filter
const filteredWords = new Set([
  // Placeholder - would be populated from config
]);

// Fetch Georgian translations from OpenAI
async function getTranslationsFromOpenAI(englishWord, conversationContext) {
  const apiKey = getOpenAIKey();
  if (!apiKey) {
    throw new Error('OpenAI API key not configured');
  }
  
  const contextStr = buildContextString(conversationContext);
  
  const systemPrompt = `You are a Georgian language expert helping English speakers learn Georgian naturally through chat.
User frequently uses the English word "${englishWord}" in conversation.
Suggest 3 natural Georgian translations appropriate for casual messaging between friends.

Recent conversation context:
${contextStr}

Respond ONLY with valid JSON array in this exact format:
[
  {
    "word": "georgian_word",
    "gloss": "brief English explanation",
    "formality": "informal|neutral|formal",
    "contextHint": "when to use this"
  }
]`;

  const userPrompt = `Provide 3 Georgian translation options for the English word: "${englishWord}"

Remember to respond with ONLY a JSON array, no additional text.`;

  const body = {
    model: 'gpt-4o-mini',
    temperature: 0.4,
    max_tokens: 400,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt }
    ]
  };
  
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000); // 15s timeout
  
  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body),
      signal: controller.signal
    });
    
    clearTimeout(timeout);
    
    if (!response.ok) {
      const errText = await response.text().catch(() => '');
      throw new Error(`OpenAI error ${response.status}: ${errText}`);
    }
    
    const data = await response.json();
    const content = data.choices?.[0]?.message?.content?.trim?.() || '';
    
    // Parse JSON response
    let parsed;
    try {
      parsed = JSON.parse(content);
    } catch (e) {
      console.error('Failed to parse OpenAI response as JSON:', content);
      throw new Error('Invalid JSON response from OpenAI');
    }
    
    if (!Array.isArray(parsed)) {
      throw new Error('Response is not an array');
    }
    
    // Validate and filter suggestions
    const validSuggestions = parsed
      .filter(s => s.word && s.gloss && s.formality && s.contextHint)
      .filter(s => !filteredWords.has(s.word.toLowerCase()))
      .slice(0, 3); // Max 3 suggestions
    
    return validSuggestions;
    
  } catch (error) {
    clearTimeout(timeout);
    throw error;
  }
}

// Main Cloud Function for English→Georgian translation suggestions
exports.suggestEnglishToGeorgian = functions
  .runWith({ timeoutSeconds: 30, memory: '512MB' })
  .https.onCall(async (data, context) => {
    try {
      // Auth check
      if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
      }
      
      const { englishWord, userId, conversationId, locale } = data;
      
      // Validation
      if (!englishWord || typeof englishWord !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', 'englishWord required');
      }
      
      if (locale && locale !== 'ka-GE') {
        throw new functions.https.HttpsError('invalid-argument', 'only ka-GE locale supported');
      }
      
      const normalizedWord = englishWord.toLowerCase().trim();
      
      // Rate limiting check
      const rateLimitKey = `english_translation_rate_${userId}`;
      const rateLimitDoc = await db.collection('rateLimits').doc(rateLimitKey).get();
      
      if (rateLimitDoc.exists) {
        const rateLimitData = rateLimitDoc.data();
        const now = Date.now();
        const windowMs = 60 * 1000; // 1 minute
        const maxRequests = 10;
        
        if (now - rateLimitData.windowStart < windowMs && rateLimitData.count >= maxRequests) {
          throw new functions.https.HttpsError('resource-exhausted', 'Rate limit exceeded');
        }
        
        if (now - rateLimitData.windowStart >= windowMs) {
          // Reset window
          await db.collection('rateLimits').doc(rateLimitKey).set({
            windowStart: now,
            count: 1
          });
        } else {
          // Increment
          await db.collection('rateLimits').doc(rateLimitKey).update({
            count: admin.firestore.FieldValue.increment(1)
          });
        }
      } else {
        // First request
        await db.collection('rateLimits').doc(rateLimitKey).set({
          windowStart: Date.now(),
          count: 1
        });
      }
      
      // Check cache
      const cached = await checkEnglishTranslationCache(normalizedWord);
      if (cached?.suggestions) {
        console.log(JSON.stringify({ 
          event: 'english_translation_cache_hit', 
          word: normalizedWord 
        }));
        return {
          englishWord: normalizedWord,
          suggestions: cached.suggestions,
          ttl: cached.metadata?.ttl || 604800000
        };
      }
      
      // Get conversation context
      const context_messages = conversationId 
        ? await getConversationContext(conversationId, 10)
        : [];
      
      // Fetch translations from OpenAI
      const start = Date.now();
      const suggestions = await getTranslationsFromOpenAI(normalizedWord, context_messages);
      const latencyMs = Date.now() - start;
      
      console.log(JSON.stringify({ 
        event: 'english_translation_generated', 
        word: normalizedWord, 
        suggestionCount: suggestions.length,
        latencyMs 
      }));
      
      // Cache result
      await storeEnglishTranslationCache(normalizedWord, suggestions);
      
      return {
        englishWord: normalizedWord,
        suggestions,
        ttl: 7 * 24 * 60 * 60 * 1000
      };
      
    } catch (error) {
      console.error('suggestEnglishToGeorgian error:', error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError('internal', error.message || 'Unknown error');
    }
  });

// Export for use in index.js
module.exports.suggestEnglishToGeorgian = exports.suggestEnglishToGeorgian;

