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
 * Check if a word is likely a valid Georgian word
 * - Must contain only Georgian characters (U+10A0 to U+10FF)
 * - Must be between 2-20 characters long (realistic Georgian word length)
 * - No mixed scripts, numbers, or special characters
 * - No excessive character repetition (e.g., "ააააა" likely an error)
 */
function isValidGeorgianWord(word) {
  if (!word || word.length < 2 || word.length > 20) {
    return false;
  }
  
  // Only allow Georgian Unicode characters
  const georgianOnlyRegex = /^[\u10A0-\u10FF]+$/;
  if (!georgianOnlyRegex.test(word)) {
    return false;
  }
  
  // Check for excessive repetition (same character 4+ times in a row)
  // This catches typos like "ააააააა"
  const repetitionRegex = /(.)\1{3,}/;
  if (repetitionRegex.test(word)) {
    return false;
  }
  
  // Check for realistic character distribution
  // Georgian words typically have a mix of vowels and consonants
  const chars = Array.from(word);
  const uniqueChars = new Set(chars);
  
  // If 80%+ of the word is the same character, it's likely an error
  if (uniqueChars.size === 1 && word.length > 2) {
    return false;
  }
  
  return true;
}

/**
 * Extract valid Georgian words from text
 * Filters out likely misspellings, mixed-script, or non-Georgian words
 * Note: Uses heuristics (not a full dictionary) to filter obvious errors
 */
function extractValidGeorgianWords(text) {
  if (!text) return [];
  
  // Split by whitespace and punctuation
  const words = text.split(/[\s.,!?;:()[\]{}"""''\-—]+/);
  
  // Filter to only valid Georgian words using heuristics
  const validWords = words.filter(word => isValidGeorgianWord(word));
  
  // Log filtering stats for debugging
  if (words.length > 0 && validWords.length < words.length) {
    const filtered = words.length - validWords.length;
    console.log(`Filtered ${filtered}/${words.length} words from message`);
  }
  
  return validWords;
}

/**
 * Build conversation summaries for GPT-4 context
 * Only includes valid, correctly-spelled Georgian words
 */
function buildConversationContext(conversations) {
  let context = '';
  let totalWordsIncluded = 0;
  let totalMessagesProcessed = 0;
  
  conversations.forEach((conv, index) => {
    context += `\n--- Conversation ${index + 1} ---\n`;
    conv.messages.forEach(msg => {
      totalMessagesProcessed++;
      
      // Extract only valid Georgian words from the message
      const validWords = extractValidGeorgianWords(msg.text);
      
      // Only include if there are valid words
      if (validWords.length > 0) {
        totalWordsIncluded += validWords.length;
        // Rejoin words with spaces
        context += `${validWords.join(' ')}\n`;
      }
    });
  });
  
  console.log(`Built context: ${totalWordsIncluded} valid words from ${totalMessagesProcessed} messages`);
  
  return context;
}

/**
 * Call GPT-4 to generate personalized practice
 */
async function generatePersonalizedPractice(conversations, apiKey) {
  const contextStr = buildConversationContext(conversations);
  
  const systemPrompt = `You are a Georgian language teacher creating personalized spelling practice for an English speaker learning Georgian.

CONTEXT:
The user has sent the following Georgian words in their conversations (only correctly-spelled, pure Georgian words are included):
${contextStr}

TASK:
Analyze the user's Georgian vocabulary for letter confusion patterns:
1. Letters they frequently misplace (wrong position in words)
2. Letters they avoid using
3. Letters they overuse incorrectly
4. Common misspellings

Generate 15 practice items focusing on these problematic letters. Each item should:
- Prioritize words from the user's conversation context when available
- If context is insufficient, supplement with common, correctly-spelled Georgian words that beginners should learn
- Use ONLY correctly spelled, real Georgian words from standard vocabulary
- NEVER use misspelled words - always use CORRECT spellings
- Choose words relevant to conversation topics or common beginner vocabulary
- Identify ONE letter position to remove from the word
- Set correctLetter to the ACTUAL letter that exists at that position in the word
- Suggest 2 confusion letters that could plausibly fit in that position but are wrong
- Consider: visual similarity (ი/უ), phonetic similarity (ა/ო), position-specific patterns, and the user's actual confusion patterns

Respond ONLY with valid JSON array:
[
  {
    "word": "სახლი",
    "missingIndex": 1,
    "correctLetter": "ა",
    "confusionLetters": ["ო", "ე"],
    "explanation": "Common word - house",
    "englishMeaning": "house"
  }
]

CRITICAL VALIDATION RULES:
- Use ONLY real, correctly-spelled Georgian words from standard vocabulary
- NEVER include misspelled, invented, or nonsense words
- When supplementing beyond user context, use common beginner words (გამარჯობა, სახლი, წიგნი, etc.)
- ALL words must follow the same standards whether from context or supplemented
- missingIndex must be valid (0 to word.length-1)
- correctLetter MUST be the actual character at word[missingIndex]
  Example: if word="სახლი" and missingIndex=1, then correctLetter MUST be "ა" (the 2nd character)
- confusionLetters must be 2 DIFFERENT Georgian letters that are NOT the correctLetter
- Use only Georgian script (Unicode U+10A0 to U+10FF)
- Focus on letters user struggles with based on their messages (or common confusion pairs if supplementing)
- Keep explanations brief and helpful (under 80 characters)
- Return exactly 15 items`;

  const userPrompt = 'Analyze the conversation history and generate 15 personalized spelling practice items. If the vocabulary context is limited, supplement with correctly-spelled common Georgian words that beginners should learn. Focus on letters the user struggles with or commonly confused letter pairs.';
  
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
- NEVER use misspelled, invented, or nonsense words
- Choose common, useful Georgian words beginners should learn (გამარჯობა, სახლი, წიგნი, მადლობა, etc.)
- Identify ONE letter position to remove from the word
- Set correctLetter to the ACTUAL letter that exists at that position in the word
- Suggest 2 confusion letters that could plausibly fit in that position but are wrong
- Consider: visual similarity (ი/უ), phonetic similarity (ა/ო), commonly confused pairs (ე/ი, ბ/დ, გ/ყ)

Respond ONLY with valid JSON array:
[
  {
    "word": "გამარჯობა",
    "missingIndex": 3,
    "correctLetter": "ა",
    "confusionLetters": ["ო", "ე"],
    "explanation": "Common greeting",
    "englishMeaning": "hello"
  }
]

CRITICAL VALIDATION RULES:
- Use ONLY real, correctly-spelled Georgian words from standard vocabulary
- NEVER include misspelled, invented, or nonsense words
- ALL words must be common beginner vocabulary that learners should know
- missingIndex must be valid (0 to word.length-1)
- correctLetter MUST be the actual character at word[missingIndex]
  Example: if word="გამარჯობა" and missingIndex=3, then correctLetter MUST be "ა" (the 4th character)
- confusionLetters must be 2 DIFFERENT Georgian letters that are NOT the correctLetter
- Use only Georgian script (Unicode U+10A0 to U+10FF)
- Focus on commonly confused letters (ი/უ, ა/ო, ე/ი, ბ/დ, გ/ყ, etc.)
- Keep explanations brief and helpful (under 80 characters)
- Return exactly 15 items`;

  const userPrompt = 'Generate 15 spelling practice items using common, correctly-spelled Georgian words that beginners should learn. Focus on commonly confused letter pairs.';
  
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
    
    // Add IDs, validate, and assemble options
    // Filter out invalid items instead of throwing
    const items = parsed.map((item, index) => {
      try {
        // Validate structure
        if (!item.word || !item.correctLetter || !Array.isArray(item.confusionLetters) || !item.englishMeaning) {
          console.warn(`Item ${index}: Invalid structure - skipping`);
          return null;
        }
        
        // Validate confusionLetters array has exactly 2 letters
        if (item.confusionLetters.length !== 2) {
          console.warn(`Item ${index}: confusionLetters must have exactly 2 letters, got ${item.confusionLetters.length} - skipping`);
          return null;
        }
        
        // Validate missingIndex is within word bounds
        // Use Array.from() to properly handle Georgian Unicode characters
        const wordChars = Array.from(item.word);
        const wordLength = wordChars.length;
        let missingIndex = item.missingIndex ?? 0;
        
        if (missingIndex < 0 || missingIndex >= wordLength) {
          console.warn(`Item ${index}: invalid missingIndex ${missingIndex} for word "${item.word}" (length ${wordLength}) - skipping`);
          return null;
        }
        
        // CRITICAL: Validate that correctLetter matches the actual letter at missingIndex
        const actualLetterAtIndex = wordChars[missingIndex];
        if (item.correctLetter !== actualLetterAtIndex) {
          console.warn(`Item ${index}: GPT-4 mismatch - correctLetter "${item.correctLetter}" != actual "${actualLetterAtIndex}" at index ${missingIndex} in word "${item.word}" - skipping`);
          return null;
        }
        
        // Assemble options: correct letter + 2 confusion letters, then shuffle
        const options = [
          item.correctLetter,
          item.confusionLetters[0],
          item.confusionLetters[1]
        ].sort(() => Math.random() - 0.5);
        
        // Final validation: ensure no duplicate letters in options
        const uniqueOptions = new Set(options);
        if (uniqueOptions.size !== 3) {
          console.warn(`Item ${index}: Duplicate letters in options for word "${item.word}" - skipping`);
          return null;
        }
        
        return {
          id: `${Date.now()}_${index}`,
          word: item.word,
          missingIndex: missingIndex,
          correctLetter: item.correctLetter,
          options: options,
          explanation: item.explanation || '',
          englishMeaning: item.englishMeaning
        };
      } catch (error) {
        console.warn(`Item ${index}: Validation error - ${error.message} - skipping`);
        return null;
      }
    }).filter(item => item !== null); // Remove invalid items
    
    // Ensure we have at least some valid items
    if (items.length === 0) {
      throw new Error('GPT-4 returned no valid practice items');
    }
    
    if (items.length < 10) {
      console.warn(`Only ${items.length} valid items out of ${parsed.length} - some items were rejected`);
    }
    
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
      const forceRefresh = data.forceRefresh === true;
      
      // Rate limiting
      await checkRateLimit(userId);
      
      // Check cache first (unless force refresh requested)
      if (!forceRefresh) {
        const cached = await checkPracticeCache(userId);
        if (cached) {
          console.log(`Returning cached batch for user ${userId}`);
          return {
            batch: cached.batch,
            source: cached.source,
            messageCount: cached.metadata.messageCount
          };
        }
      } else {
        console.log(`Force refresh requested for user ${userId} - bypassing cache`);
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

