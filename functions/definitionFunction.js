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

// Util: write SSE event
function sseWrite(res, data) {
  res.write(`data: ${JSON.stringify(data)}\n\n`);
}

// Cache helpers for definitions
function definitionHash(word) {
  const crypto = require('crypto');
  return crypto.createHash('md5').update(word.trim().toLowerCase()).digest('hex');
}

async function checkDefinitionCache(word) {
  const hash = definitionHash(word);
  const doc = await db.collection('definitionCache').doc(hash).get();
  if (!doc.exists) return null;
  
  const data = doc.data();
  
  // Update hit count
  await doc.ref.update({
    'metadata.hitCount': admin.firestore.FieldValue.increment(1),
    'metadata.lastUsed': admin.firestore.FieldValue.serverTimestamp()
  });
  
  return data;
}

async function storeDefinitionCache(word, definition, example) {
  const hash = definitionHash(word);
  const ref = db.collection('definitionCache').doc(hash);
  await ref.set({
    wordKey: word,
    definition,
    example,
    metadata: {
      hitCount: 0,
      firstCached: admin.firestore.FieldValue.serverTimestamp(),
      lastUsed: admin.firestore.FieldValue.serverTimestamp(),
      model: 'gpt-4o-mini'
    }
  }, { merge: true });
}

// Get conversation context (last N messages)
async function getConversationContext(conversationId, beforeTs, limit = 5) {
  try {
    const q = await db.collection('messages')
      .where('conversationId', '==', conversationId)
      .where('timestamp', '<', beforeTs)
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
  
  return context.slice(0, 5)
    .map(m => {
      const text = String(m.text || '');
      return `- ${text}`;
    })
    .join('\n');
}

// Fetch definition from OpenAI
async function getDefinitionFromOpenAI(word, fullContext, conversationContext) {
  const apiKey = getOpenAIKey();
  if (!apiKey) {
    throw new Error('OpenAI API key not configured');
  }
  
  const contextStr = buildContextString(conversationContext);
  
  const systemPrompt = `You are a Georgian language expert helping English speakers learn Georgian vocabulary.

Your task: Provide an accurate English definition of Georgian words, considering their usage in casual conversation.

Recent conversation context (to understand usage):
${contextStr}

IMPORTANT:
- Give the ENGLISH meaning/translation of the Georgian word
- Be accurate and concise (1-2 sentences max)
- Include usage context (formal/informal, when to use)
- Example must be natural Georgian, not translated

Respond ONLY with valid JSON in this exact format:
{
  "definition": "Clear English explanation of what this Georgian word means",
  "example": "Natural Georgian sentence using this word (keep it authentic, don't translate)"
}`;

  const userPrompt = `What does the Georgian word "${word}" mean in English?

This word appeared in the sentence: "${fullContext}"

Provide accurate definition and example. JSON only, no extra text.`;

  const body = {
    model: 'gpt-4o-mini',
    temperature: 0.3,
    max_tokens: 300,
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
    
    if (!parsed.definition || !parsed.example) {
      throw new Error('Missing definition or example in response');
    }
    
    return {
      definition: parsed.definition,
      example: parsed.example
    };
    
  } catch (error) {
    clearTimeout(timeout);
    throw error;
  }
}

// Main Cloud Function for word definitions
exports.getWordDefinition = functions
  .runWith({ timeoutSeconds: 30, memory: '512MB' })
  .https.onRequest(async (req, res) => {
    res.set({
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive'
    });
    
    // Auth check
    try {
      const authHeader = req.headers.authorization || '';
      const token = authHeader.startsWith('Bearer ') ? authHeader.substring(7) : null;
      if (!token) throw new Error('missing token');
      await admin.auth().verifyIdToken(token);
    } catch (e) {
      sseWrite(res, { type: 'error', error: 'unauthorized' });
      return res.end();
    }
    
    const { word, conversationId, fullContext, timestamp } = req.body || {};
    
    if (!word) {
      sseWrite(res, { type: 'error', error: 'invalid_request' });
      return res.end();
    }
    
    try {
      const normalizedWord = word.toLowerCase().trim();
      
      // 1) Check cache
      const cached = await checkDefinitionCache(normalizedWord);
      if (cached) {
        console.log(JSON.stringify({ event: 'definition_cache_hit', word: normalizedWord }));
        sseWrite(res, {
          type: 'final',
          word: normalizedWord,
          definition: cached.definition,
          example: cached.example,
          cached: true
        });
        return res.end();
      }
      
      // 2) Get conversation context
      const context = conversationId && timestamp 
        ? await getConversationContext(conversationId, timestamp, 5)
        : [];
      
      // 3) Fetch definition from OpenAI
      const start = Date.now();
      const result = await getDefinitionFromOpenAI(normalizedWord, fullContext || '', context);
      const latencyMs = Date.now() - start;
      
      // 4) Store in cache
      await storeDefinitionCache(normalizedWord, result.definition, result.example);
      
      console.log(JSON.stringify({ 
        event: 'definition_generated', 
        word: normalizedWord, 
        latencyMs 
      }));
      
      // 5) Send response
      sseWrite(res, {
        type: 'final',
        word: normalizedWord,
        definition: result.definition,
        example: result.example,
        cached: false
      });
      
      return res.end();
      
    } catch (error) {
      console.error(JSON.stringify({ 
        event: 'definition_error', 
        word, 
        error: String(error) 
      }));
      sseWrite(res, { 
        type: 'error', 
        error: error.message || 'unknown_error' 
      });
      return res.end();
    }
  });

// Export for use in index.js
module.exports.getWordDefinition = exports.getWordDefinition;

