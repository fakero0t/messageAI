/**
 * practiceFunction.js
 * AI V4: Context-Aware Smart Practice
 * 
 * Generates personalized spelling practice by analyzing user's conversation history
 * Uses GPT-4 to identify letter confusion patterns and create targeted exercises
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const fetch = require('node-fetch');

const db = admin.firestore();

// OpenAI key helper
function getOpenAIKey() {
  try {
    const cfg = functions.config();
    if (cfg && cfg.openai && cfg.openai.key) return cfg.openai.key;
  } catch (_) {}
  return process.env.OPENAI_API_KEY;
}

// Message count threshold for personalized practice
const MIN_MESSAGES_FOR_PERSONALIZED = 20;

/**
 * Fetch user's sent messages grouped by conversation
 * Returns last 50 messages per conversation
 */
async function fetchUserMessages(userId) {
  try {
    const messagesRef = db.collection('messages');
    const snapshot = await messagesRef
      .where('senderId', '==', userId)
      .orderBy('timestamp', 'desc')
      .limit(500) // Get up to 500 recent messages
      .get();
    
    if (snapshot.empty) {
      return { count: 0, conversations: [] };
    }
    
    // Group by conversation
    const conversationMap = new Map();
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const convId = data.conversationId;
      
      if (!conversationMap.has(convId)) {
        conversationMap.set(convId, []);
      }
      
      // Only include Georgian text messages (not images, etc.)
      if (data.text && hasGeorgianScript(data.text)) {
        conversationMap.get(convId).push({
          text: data.text,
          timestamp: data.timestamp
        });
      }
    });
    
    // Take last 50 messages per conversation
    const conversations = [];
    let totalCount = 0;
    
    for (const [convId, messages] of conversationMap.entries()) {
      const last50 = messages.slice(0, 50);
      conversations.push({
        conversationId: convId,
        messages: last50
      });
      totalCount += last50.length;
    }
    
    return { count: totalCount, conversations };
    
  } catch (error) {
    console.error('Error fetching user messages:', error);
    throw error;
  }
}

/**
 * Check if text contains Georgian script
 */
function hasGeorgianScript(text) {
  const georgianRegex = /[\u10A0-\u10FF]/;
  return georgianRegex.test(text);
}

/**
 * Build conversation summaries for GPT-4 context
 */
function buildConversationContext(conversations) {
  let context = '';
  
  conversations.forEach((conv, index) => {
    context += `\n--- Conversation ${index + 1} ---\n`;
    conv.messages.forEach(msg => {
      context += `${msg.text}\n`;
    });
  });
  
  return context;
}

/**
 * Call GPT-4 to generate personalized practice
 */
async function generatePersonalizedPractice(conversations, apiKey) {
  const contextStr = buildConversationContext(conversations);
  
  const systemPrompt = `You are a Georgian language teacher creating personalized spelling practice for an English speaker learning Georgian.

CONTEXT:
The user has sent the following messages in their conversations:
${contextStr}

TASK:
Analyze the user's Georgian text for letter confusion patterns:
1. Letters they frequently misplace (wrong position in words)
2. Letters they avoid using
3. Letters they overuse incorrectly
4. Common misspellings

Generate 15 practice items focusing on these problematic letters. Each item should:
- Use ONLY correctly spelled, real Georgian words from standard vocabulary
- NEVER use misspelled words from the user's messages
- If the user misspells a word, use the CORRECT spelling in practice
- Choose words relevant to conversation topics
- Remove ONE letter that the user struggles with
- Provide 3 letter choices:
  * The correct letter
  * A commonly confused Georgian letter (like ი/უ, ა/ო, ე/ი)
  * A visually similar Georgian letter

Respond ONLY with valid JSON array:
[
  {
    "word": "complete_georgian_word",
    "missingIndex": 3,
    "correctLetter": "ი",
    "options": ["ი", "უ", "ო"],
    "explanation": "This letter is commonly used in this position for verbs"
  }
]

CRITICAL RULES:
- Use ONLY real Georgian words with correct spelling
- NEVER include misspelled or invented words
- Validate that each word is proper Georgian vocabulary
- Use only Georgian script (Unicode U+10A0 to U+10FF)
- Ensure options are randomized (correct letter not always first)
- Focus on letters user struggles with based on their messages
- Keep explanations brief and helpful (under 80 characters)
- Return exactly 15 items`;

  const userPrompt = 'Analyze the conversation history and generate personalized spelling practice focusing on letters the user struggles with.';
  
  return await callGPT4(systemPrompt, userPrompt, apiKey);
}

/**
 * Call GPT-4 to generate generic practice
 */
async function generateGenericPractice(apiKey) {
  const systemPrompt = `You are a Georgian language teacher creating spelling practice for an English speaker learning Georgian.

TASK:
Generate 15 practice items using common Georgian words suitable for beginners.

Each item should:
- Use ONLY correctly spelled, real Georgian words from standard vocabulary
- Choose common, useful Georgian words beginners should learn
- Remove ONE letter
- Provide 3 letter choices:
  * The correct letter
  * A commonly confused Georgian letter (like ი/უ, ა/ო, ე/ი)
  * A visually similar Georgian letter

Respond ONLY with valid JSON array:
[
  {
    "word": "გამარჯობა",
    "missingIndex": 3,
    "correctLetter": "ა",
    "options": ["ა", "ო", "ე"],
    "explanation": "Common greeting - 'hello'"
  }
]

CRITICAL RULES:
- Use ONLY real Georgian words with correct spelling
- NEVER include misspelled or invented words
- Validate that each word is proper Georgian vocabulary
- Use only Georgian script (Unicode U+10A0 to U+10FF)
- Ensure options are randomized (correct letter not always first)
- Focus on commonly confused letters (ი/უ, ა/ო, ე/ი, ბ/დ, გ/ყ, etc.)
- Keep explanations brief and helpful (under 80 characters)
- Return exactly 15 items`;

  const userPrompt = 'Generate generic spelling practice for a beginner learning Georgian.';
  
  return await callGPT4(systemPrompt, userPrompt, apiKey);
}

/**
 * Call GPT-4 API
 */
async function callGPT4(systemPrompt, userPrompt, apiKey) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 50000); // 50s timeout
  
  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        temperature: 0.3,
        max_tokens: 2000,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ]
      }),
      signal: controller.signal
    });
    
    clearTimeout(timeout);
    
    if (!response.ok) {
      const errorText = await response.text().catch(() => '');
      throw new Error(`OpenAI error ${response.status}: ${errorText}`);
    }
    
    const data = await response.json();
    const content = data.choices?.[0]?.message?.content?.trim?.() || '';
    
    // Parse JSON response
    let parsed;
    try {
      parsed = JSON.parse(content);
    } catch (e) {
      console.error('Failed to parse GPT-4 response:', content);
      throw new Error('Invalid JSON response from GPT-4');
    }
    
    // Validate structure
    if (!Array.isArray(parsed) || parsed.length === 0) {
      throw new Error('Expected non-empty array from GPT-4');
    }
    
    // Add IDs and validate each item
    const items = parsed.map((item, index) => {
      if (!item.word || !item.correctLetter || !Array.isArray(item.options)) {
        throw new Error(`Invalid item structure at index ${index}`);
      }
      
      // CRITICAL: Ensure correct letter is always in options
      let options = item.options;
      if (!options.includes(item.correctLetter)) {
        console.warn(`Item ${index}: correctLetter "${item.correctLetter}" not in options, adding it`);
        // Replace the last option with the correct letter if not present
        options = [options[0], options[1] || options[0], item.correctLetter];
      }
      
      return {
        id: `${Date.now()}_${index}`,
        word: item.word,
        missingIndex: item.missingIndex || 0,
        correctLetter: item.correctLetter,
        options: options,
        explanation: item.explanation || ''
      };
    });
    
    return items;
    
  } catch (error) {
    clearTimeout(timeout);
    throw error;
  }
}

/**
 * Check practice cache in Firestore
 */
async function checkPracticeCache(userId) {
  try {
    const cacheRef = db.collection('practiceCache').doc(userId);
    const doc = await cacheRef.get();
    
    if (!doc.exists) return null;
    
    const data = doc.data();
    const age = Date.now() - data.metadata.generatedAt;
    const ttl = 3600000; // 1 hour
    
    if (age > ttl) {
      console.log(`Cache expired for user ${userId}`);
      return null;
    }
    
    console.log(`Cache hit for user ${userId}`);
    return data;
    
  } catch (error) {
    console.error('Error checking cache:', error);
    return null;
  }
}

/**
 * Store practice batch in cache
 */
async function storePracticeCache(userId, batch, source, messageCount) {
  try {
    const cacheRef = db.collection('practiceCache').doc(userId);
    await cacheRef.set({
      userId,
      batch,
      source,
      metadata: {
        generatedAt: Date.now(),
        ttl: 3600000, // 1 hour
        messageCount,
        model: 'gpt-4'
      }
    });
    
    console.log(`Stored cache for user ${userId}`);
  } catch (error) {
    console.error('Error storing cache:', error);
  }
}

/**
 * Rate limiting check
 */
async function checkRateLimit(userId) {
  const rateLimitKey = `practice_rate_${userId}`;
  const rateLimitDoc = await db.collection('rateLimits').doc(rateLimitKey).get();
  
  const now = Date.now();
  const windowMs = 60 * 1000; // 1 minute
  const maxRequests = 5;
  
  if (rateLimitDoc.exists) {
    const data = rateLimitDoc.data();
    
    if (now - data.windowStart < windowMs && data.count >= maxRequests) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'Rate limit exceeded. Please wait a moment.'
      );
    }
    
    if (now - data.windowStart >= windowMs) {
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
      windowStart: now,
      count: 1
    });
  }
}

/**
 * Main function: Generate practice batch
 */
exports.generatePractice = functions
  .runWith({ timeoutSeconds: 60, memory: '1GB' })
  .https.onCall(async (data, context) => {
    const startTime = Date.now();
    
    try {
      // Auth check
      if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
      }
      
      const userId = context.auth.uid;
      
      // Rate limiting
      await checkRateLimit(userId);
      
      // Check cache first
      const cached = await checkPracticeCache(userId);
      if (cached) {
        return {
          batch: cached.batch,
          source: cached.source,
          messageCount: cached.metadata.messageCount
        };
      }
      
      // Get OpenAI key
      const apiKey = getOpenAIKey();
      if (!apiKey) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'OpenAI API key not configured'
        );
      }
      
      // Fetch user's messages
      const { count, conversations } = await fetchUserMessages(userId);
      
      let batch;
      let source;
      
      if (count < MIN_MESSAGES_FOR_PERSONALIZED) {
        // Generate generic practice
        console.log(`User ${userId} has ${count} messages - generating generic practice`);
        batch = await generateGenericPractice(apiKey);
        source = 'generic';
      } else {
        // Generate personalized practice
        console.log(`User ${userId} has ${count} messages - generating personalized practice`);
        batch = await generatePersonalizedPractice(conversations, apiKey);
        source = 'personalized';
      }
      
      // Store in cache
      await storePracticeCache(userId, batch, source, count);
      
      const latencyMs = Date.now() - startTime;
      console.log(JSON.stringify({
        event: 'practice_batch_generated',
        userId,
        source,
        itemCount: batch.length,
        messageCount: count,
        latencyMs
      }));
      
      return {
        batch,
        source,
        messageCount: count
      };
      
    } catch (error) {
      console.error('generatePractice error:', error);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError('internal', error.message || 'Unknown error');
    }
  });

