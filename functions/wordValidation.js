/**
 * wordValidation.js
 * PR1-PR5: Word Validation System
 * 
 * This module implements the 5-signal automated validation system for Georgian words.
 * Ensures only legitimate Georgian words (formal and slang) are used in practice questions.
 */

const admin = require('firebase-admin');
const db = admin.firestore();

// ============================================================================
// PR1: Database Foundation & Word Tracking
// ============================================================================

/**
 * Track word usage by a specific user
 * Increments usage count and adds user to unique user list
 * @param {string} word - Georgian word to track
 * @param {string} userId - User ID who used the word
 * @returns {Promise<void>}
 */
async function trackWordUsage(word, userId) {
  if (!word || !userId) {
    console.warn('[WordValidation] trackWordUsage: Missing word or userId');
    return;
  }
  
  const normalized = word.toLowerCase().trim();
  
  try {
    const wordStatsRef = db.collection('wordStats').doc(normalized);
    
    // Use atomic operations for concurrency safety
    await wordStatsRef.set({
      word: word, // Preserve original case
      count: admin.firestore.FieldValue.increment(1),
      userIds: admin.firestore.FieldValue.arrayUnion(userId),
      lastSeen: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    
    // Set firstSeen only if document is new
    const doc = await wordStatsRef.get();
    if (!doc.data()?.firstSeen) {
      await wordStatsRef.update({
        firstSeen: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    
    console.log(`✅ [WordStats] Tracked: ${word} by user ${userId}`);
    
  } catch (error) {
    console.error(`❌ [WordStats] Failed to track "${word}": ${error.message}`);
    // Don't throw - tracking is non-critical
  }
}

/**
 * Get word statistics from database
 * @param {string} word - Georgian word to lookup
 * @returns {Promise<Object|null>} Word stats or null if not found
 */
async function getWordStats(word) {
  if (!word) {
    return null;
  }
  
  const normalized = word.toLowerCase().trim();
  
  try {
    const doc = await db.collection('wordStats').doc(normalized).get();
    
    if (!doc.exists) {
      return null;
    }
    
    const data = doc.data();
    
    return {
      word: data.word,
      count: data.count || 0,
      userIds: data.userIds || [],
      uniqueUsers: (data.userIds || []).length,
      firstSeen: data.firstSeen,
      lastSeen: data.lastSeen
    };
    
  } catch (error) {
    console.error(`❌ [WordStats] Failed to get stats for "${word}": ${error.message}`);
    return null;
  }
}

// ============================================================================
// PR2: Free Validation Signals (Crowd + Patterns)
// ============================================================================

/**
 * Validate word based on crowd wisdom
 * Uses word usage statistics to determine validity
 * @param {string} word - Georgian word to validate
 * @returns {Promise<Object>} { valid, confidence, source, uniqueUsers }
 */
async function validateByCrowd(word) {
  if (!word) {
    return { valid: false, confidence: 0, source: 'crowd_insufficient' };
  }
  
  try {
    // Get word statistics
    const stats = await getWordStats(word);
    
    if (!stats) {
      return { valid: false, confidence: 0, source: 'crowd_insufficient', uniqueUsers: 0 };
    }
    
    const uniqueUsers = stats.uniqueUsers;
    
    // Apply thresholds based on unique user count
    if (uniqueUsers >= 10) {
      // Strong crowd signal: 10+ different users use this word
      console.log(`✅ [Crowd] Strong signal: ${word} (${uniqueUsers} users)`);
      return {
        valid: true,
        confidence: 0.95,
        source: 'crowd_strong',
        uniqueUsers: uniqueUsers
      };
    } else if (uniqueUsers >= 5) {
      // Medium crowd signal: 5-9 users
      console.log(`✅ [Crowd] Medium signal: ${word} (${uniqueUsers} users)`);
      return {
        valid: true,
        confidence: 0.85,
        source: 'crowd_medium',
        uniqueUsers: uniqueUsers
      };
    } else if (uniqueUsers >= 3) {
      // Weak crowd signal: 3-4 users
      console.log(`⚠️ [Crowd] Weak signal: ${word} (${uniqueUsers} users)`);
      return {
        valid: true,
        confidence: 0.60,
        source: 'crowd_weak',
        uniqueUsers: uniqueUsers
      };
    } else {
      // Insufficient crowd data
      console.log(`❌ [Crowd] Insufficient: ${word} (${uniqueUsers} users)`);
      return {
        valid: false,
        confidence: 0,
        source: 'crowd_insufficient',
        uniqueUsers: uniqueUsers
      };
    }
    
  } catch (error) {
    console.error(`❌ [Crowd] Error validating "${word}": ${error.message}`);
    return { valid: false, confidence: 0, source: 'crowd_error' };
  }
}

/**
 * Check if character is Georgian vowel
 * @param {string} char - Single character
 * @returns {boolean}
 */
function isGeorgianVowel(char) {
  const vowels = ['ა', 'ე', 'ი', 'ო', 'უ'];
  return vowels.includes(char);
}

/**
 * Check if character is Georgian consonant
 * @param {string} char - Single character
 * @returns {boolean}
 */
function isGeorgianConsonant(char) {
  // Georgian Unicode range: U+10A0 to U+10FF
  const code = char.charCodeAt(0);
  const isGeorgian = code >= 0x10A0 && code <= 0x10FF;
  
  return isGeorgian && !isGeorgianVowel(char);
}

/**
 * Validate word based on Georgian linguistic patterns
 * @param {string} word - Georgian word to validate
 * @returns {Object} { valid, confidence, source, patterns }
 */
function validateByPatterns(word) {
  if (!word) {
    return { valid: false, confidence: 0, source: 'linguistic_patterns' };
  }
  
  const chars = Array.from(word);
  const length = chars.length;
  
  // Initialize pattern checks
  const patterns = {
    hasOnlyGeorgian: true,
    hasReasonableLength: length >= 2 && length <= 20,
    hasReasonableVowelRatio: false,
    hasReasonableConsonants: true,
    noExcessiveRepetition: true,
    hasBothVowelsAndConsonants: false
  };
  
  // Check 1: Only Georgian characters (U+10A0 to U+10FF)
  for (const char of chars) {
    const code = char.charCodeAt(0);
    if (code < 0x10A0 || code > 0x10FF) {
      patterns.hasOnlyGeorgian = false;
      break;
    }
  }
  
  // If not Georgian, reject immediately
  if (!patterns.hasOnlyGeorgian) {
    return {
      valid: false,
      confidence: 0,
      source: 'linguistic_patterns',
      patterns: patterns
    };
  }
  
  // Check 2: Vowel and consonant counts
  let vowelCount = 0;
  let consonantCount = 0;
  let consecutiveConsonants = 0;
  let maxConsecutiveConsonants = 0;
  
  for (const char of chars) {
    if (isGeorgianVowel(char)) {
      vowelCount++;
      consecutiveConsonants = 0;
    } else if (isGeorgianConsonant(char)) {
      consonantCount++;
      consecutiveConsonants++;
      maxConsecutiveConsonants = Math.max(maxConsecutiveConsonants, consecutiveConsonants);
    }
  }
  
  // Check 3: Vowel ratio (Georgian words typically have 15-50% vowels)
  const vowelRatio = vowelCount / length;
  patterns.hasReasonableVowelRatio = vowelRatio >= 0.15 && vowelRatio <= 0.50;
  
  // Check 4: Max consecutive consonants (Georgian allows up to 6, e.g., "მწვრთნელი")
  patterns.hasReasonableConsonants = maxConsecutiveConsonants <= 6;
  
  // Check 5: No excessive repetition (same character 4+ times in a row)
  const repetitionRegex = /(.)\1{3,}/;
  patterns.noExcessiveRepetition = !repetitionRegex.test(word);
  
  // Check 6: Has both vowels and consonants
  patterns.hasBothVowelsAndConsonants = vowelCount > 0 && consonantCount > 0;
  
  // Count how many patterns match
  const patternChecks = Object.values(patterns);
  const matchCount = patternChecks.filter(v => v === true).length;
  const totalChecks = patternChecks.length;
  const confidence = matchCount / totalChecks;
  
  // Valid if at least 4 out of 6 patterns match
  const valid = matchCount >= 4;
  
  if (valid) {
    console.log(`✅ [Patterns] Valid: ${word} (${matchCount}/${totalChecks} patterns)`);
  } else {
    console.log(`❌ [Patterns] Invalid: ${word} (${matchCount}/${totalChecks} patterns)`);
  }
  
  return {
    valid: valid,
    confidence: confidence,
    source: 'linguistic_patterns',
    patterns: patterns
  };
}

// ============================================================================
// PR3: GPT-Based Validation Signals
// ============================================================================

/**
 * Validate word using GPT-4o-mini
 * Asks GPT if a word is a real Georgian word (formal or slang)
 * @param {string} word - Georgian word to validate
 * @param {string} apiKey - OpenAI API key
 * @returns {Promise<Object>} { valid, confidence, source, gptResponse }
 */
async function validateByGPT(word, apiKey) {
  if (!word || !apiKey) {
    return { valid: false, confidence: 0, source: 'gpt_error', error: 'Missing word or API key' };
  }
  
  try {
    const axios = require('axios');
    
    // GPT prompt designed for high accuracy
    const prompt = `Is "${word}" a real Georgian (ქართული) word? This includes:
- Standard Georgian words from dictionaries
- Common slang terms used by Georgian speakers
- Regional dialect words
- Modern internet slang in Georgian

Answer with ONLY one word: "YES" if it's a real Georgian word (formal or slang), "NO" if it's gibberish, a typo, or not Georgian.`;

    const response = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'You are a Georgian language expert. Answer questions about Georgian words with YES or NO only.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.1, // Low temperature for consistency
        max_tokens: 10    // Only need YES or NO
      },
      {
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        },
        timeout: 10000 // 10 second timeout
      }
    );
    
    const gptAnswer = response.data.choices[0].message.content.trim().toUpperCase();
    
    // Parse GPT response
    let valid = false;
    let confidence = 0;
    
    if (gptAnswer.includes('YES')) {
      valid = true;
      confidence = 0.85; // High confidence but not absolute (GPT can be wrong)
      console.log(`✅ [GPT] Valid: ${word}`);
    } else if (gptAnswer.includes('NO')) {
      valid = false;
      confidence = 0.15; // Low confidence = probably invalid
      console.log(`❌ [GPT] Invalid: ${word}`);
    } else {
      // Unexpected response
      console.log(`⚠️ [GPT] Unexpected response for "${word}": ${gptAnswer}`);
      valid = false;
      confidence = 0;
    }
    
    return {
      valid: valid,
      confidence: confidence,
      source: 'gpt_validation',
      gptResponse: gptAnswer
    };
    
  } catch (error) {
    console.error(`❌ [GPT] Error validating "${word}": ${error.message}`);
    
    // Don't fail validation on API errors - return inconclusive
    return {
      valid: false,
      confidence: 0,
      source: 'gpt_error',
      error: error.message
    };
  }
}

/**
 * Validate word using translation round-trip
 * Translates word to English and back to Georgian
 * If result matches original, word is probably valid
 * @param {string} word - Georgian word to validate
 * @param {string} apiKey - OpenAI API key
 * @returns {Promise<Object>} { valid, confidence, source, translation, roundTrip }
 */
async function validateByTranslation(word, apiKey) {
  if (!word || !apiKey) {
    return { valid: false, confidence: 0, source: 'translation_error', error: 'Missing word or API key' };
  }
  
  try {
    const axios = require('axios');
    
    // Step 1: Translate Georgian → English
    const toEnglishResponse = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'You are a Georgian-English translator. Translate words accurately. If the word is gibberish or not Georgian, respond with "INVALID".'
          },
          {
            role: 'user',
            content: `Translate this Georgian word to English: "${word}". Reply with ONLY the English translation, nothing else. If it's not a real Georgian word, reply "INVALID".`
          }
        ],
        temperature: 0.1,
        max_tokens: 50
      },
      {
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        },
        timeout: 10000
      }
    );
    
    const englishTranslation = toEnglishResponse.data.choices[0].message.content.trim();
    
    // Check if GPT said it's invalid
    if (englishTranslation.toUpperCase().includes('INVALID')) {
      console.log(`❌ [Translation] Invalid word: ${word}`);
      return {
        valid: false,
        confidence: 0.10,
        source: 'translation_invalid',
        translation: null
      };
    }
    
    // Step 2: Translate English → Georgian
    const toGeorgianResponse = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'You are an English-Georgian translator. Translate words accurately.'
          },
          {
            role: 'user',
            content: `Translate this English word to Georgian: "${englishTranslation}". Reply with ONLY the Georgian translation, nothing else.`
          }
        ],
        temperature: 0.1,
        max_tokens: 50
      },
      {
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        },
        timeout: 10000
      }
    );
    
    const georgianRoundTrip = toGeorgianResponse.data.choices[0].message.content.trim();
    
    // Step 3: Compare original with round-trip result
    const normalizedOriginal = word.toLowerCase().trim();
    const normalizedRoundTrip = georgianRoundTrip.toLowerCase().trim();
    
    // Check for exact match or very close match
    const exactMatch = normalizedOriginal === normalizedRoundTrip;
    
    // Also check if round-trip is contained in original or vice versa (handles variations)
    const closeMatch = normalizedOriginal.includes(normalizedRoundTrip) || 
                      normalizedRoundTrip.includes(normalizedOriginal);
    
    let valid = false;
    let confidence = 0;
    
    if (exactMatch) {
      valid = true;
      confidence = 0.90; // High confidence for exact match
      console.log(`✅ [Translation] Exact match: ${word} → ${englishTranslation} → ${georgianRoundTrip}`);
    } else if (closeMatch && georgianRoundTrip.length >= 2) {
      valid = true;
      confidence = 0.70; // Medium confidence for close match
      console.log(`⚠️ [Translation] Close match: ${word} → ${englishTranslation} → ${georgianRoundTrip}`);
    } else {
      valid = false;
      confidence = 0.20; // Low confidence = probably not a real word
      console.log(`❌ [Translation] No match: ${word} → ${englishTranslation} → ${georgianRoundTrip}`);
    }
    
    return {
      valid: valid,
      confidence: confidence,
      source: 'translation_roundtrip',
      translation: englishTranslation,
      roundTrip: georgianRoundTrip
    };
    
  } catch (error) {
    console.error(`❌ [Translation] Error validating "${word}": ${error.message}`);
    
    return {
      valid: false,
      confidence: 0,
      source: 'translation_error',
      error: error.message
    };
  }
}

// ============================================================================
// PR4: Semantic Embedding Validation
// ============================================================================

// Baseline Georgian words for semantic comparison
// These are common, definitely valid Georgian words across different categories
const BASELINE_GEORGIAN_WORDS = [
  // Greetings
  'გამარჯობა', 'ნახვამდის', 'მადლობა',
  // Common nouns
  'სახლი', 'წიგნი', 'მანქანა', 'ადამიანი', 'ქალი', 'კაცი',
  // Verbs
  'მიდის', 'ვარ', 'არის', 'ვიცი', 'მინდა',
  // Adjectives
  'კარგი', 'ცუდი', 'დიდი', 'პატარა', 'ლამაზი',
  // Time/place
  'დღეს', 'ხვალ', 'აქ', 'იქ', 'როდის',
  // Questions
  'რა', 'ვინ', 'როგორ', 'რატომ', 'სად'
];

// In-memory cache for embeddings (avoids recomputing baseline embeddings)
const embeddingCache = new Map();

/**
 * Calculate cosine similarity between two vectors
 * @param {Array<number>} vecA - First vector
 * @param {Array<number>} vecB - Second vector
 * @returns {number} Similarity score (0-1, higher is more similar)
 */
function cosineSimilarity(vecA, vecB) {
  if (!vecA || !vecB || vecA.length !== vecB.length) {
    return 0;
  }
  
  let dotProduct = 0;
  let normA = 0;
  let normB = 0;
  
  for (let i = 0; i < vecA.length; i++) {
    dotProduct += vecA[i] * vecB[i];
    normA += vecA[i] * vecA[i];
    normB += vecB[i] * vecB[i];
  }
  
  if (normA === 0 || normB === 0) {
    return 0;
  }
  
  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
}

/**
 * Get embedding vector for a word using OpenAI's embedding API
 * @param {string} word - Word to get embedding for
 * @param {string} apiKey - OpenAI API key
 * @returns {Promise<Array<number>>} Embedding vector
 */
async function getEmbedding(word, apiKey) {
  if (!word || !apiKey) {
    throw new Error('Missing word or API key');
  }
  
  // Check cache first
  const cacheKey = word.toLowerCase().trim();
  if (embeddingCache.has(cacheKey)) {
    return embeddingCache.get(cacheKey);
  }
  
  try {
    const axios = require('axios');
    
    const response = await axios.post(
      'https://api.openai.com/v1/embeddings',
      {
        model: 'text-embedding-3-small',
        input: word,
        encoding_format: 'float'
      },
      {
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        },
        timeout: 10000
      }
    );
    
    const embedding = response.data.data[0].embedding;
    
    // Cache the embedding (limit cache size)
    if (embeddingCache.size < 1000) {
      embeddingCache.set(cacheKey, embedding);
    }
    
    return embedding;
    
  } catch (error) {
    console.error(`❌ [Embedding] Error getting embedding for "${word}": ${error.message}`);
    throw error;
  }
}

/**
 * Validate word using semantic embeddings
 * Compares word's embedding to baseline Georgian words
 * @param {string} word - Georgian word to validate
 * @param {string} apiKey - OpenAI API key
 * @returns {Promise<Object>} { valid, confidence, source, avgSimilarity, maxSimilarity }
 */
async function validateBySemantics(word, apiKey) {
  if (!word || !apiKey) {
    return { valid: false, confidence: 0, source: 'semantic_error', error: 'Missing word or API key' };
  }
  
  try {
    // Get embedding for the word to validate
    const wordEmbedding = await getEmbedding(word, apiKey);
    
    // Get embeddings for baseline words (many will be cached after first run)
    const baselineEmbeddings = await Promise.all(
      BASELINE_GEORGIAN_WORDS.map(baselineWord => getEmbedding(baselineWord, apiKey))
    );
    
    // Calculate similarities to all baseline words
    const similarities = baselineEmbeddings.map((baselineEmbed, idx) => ({
      word: BASELINE_GEORGIAN_WORDS[idx],
      similarity: cosineSimilarity(wordEmbedding, baselineEmbed)
    }));
    
    // Calculate average and max similarity
    const avgSimilarity = similarities.reduce((sum, s) => sum + s.similarity, 0) / similarities.length;
    const maxSimilarity = Math.max(...similarities.map(s => s.similarity));
    
    // Find the most similar baseline word
    const mostSimilar = similarities.reduce((max, current) => 
      current.similarity > max.similarity ? current : max
    );
    
    console.log(`📊 [Semantics] "${word}": avg=${avgSimilarity.toFixed(3)}, max=${maxSimilarity.toFixed(3)}, closest="${mostSimilar.word}"`);
    
    // Validation thresholds
    // Georgian words should have reasonable similarity to other Georgian words
    // Non-Georgian or gibberish will have lower similarity
    let valid = false;
    let confidence = 0;
    
    if (avgSimilarity >= 0.70) {
      // Very high average similarity - definitely Georgian-like
      valid = true;
      confidence = 0.90;
      console.log(`✅ [Semantics] High similarity: ${word}`);
    } else if (avgSimilarity >= 0.60) {
      // Good average similarity - probably Georgian
      valid = true;
      confidence = 0.75;
      console.log(`✅ [Semantics] Good similarity: ${word}`);
    } else if (avgSimilarity >= 0.50) {
      // Moderate similarity - possibly Georgian
      valid = true;
      confidence = 0.60;
      console.log(`⚠️ [Semantics] Moderate similarity: ${word}`);
    } else {
      // Low similarity - probably not Georgian or gibberish
      valid = false;
      confidence = avgSimilarity; // Use actual similarity as confidence
      console.log(`❌ [Semantics] Low similarity: ${word}`);
    }
    
    return {
      valid: valid,
      confidence: confidence,
      source: 'semantic_embedding',
      avgSimilarity: avgSimilarity,
      maxSimilarity: maxSimilarity,
      mostSimilar: mostSimilar.word
    };
    
  } catch (error) {
    console.error(`❌ [Semantics] Error validating "${word}": ${error.message}`);
    
    return {
      valid: false,
      confidence: 0,
      source: 'semantic_error',
      error: error.message
    };
  }
}

/**
 * Clear the embedding cache (useful for testing or memory management)
 */
function clearEmbeddingCache() {
  embeddingCache.clear();
  console.log('🗑️ [Semantics] Embedding cache cleared');
}

// ============================================================================
// PR5: Master Validation Function
// ============================================================================

/**
 * Master validation function that orchestrates all validation signals
 * Intelligently combines crowd, patterns, GPT, translation, and semantics
 * 
 * @param {string} word - Georgian word to validate
 * @param {string} userId - User ID (for crowd signal)
 * @param {string} apiKey - OpenAI API key
 * @returns {Promise<Object>} Final validation result with confidence score
 */
async function validateGeorgianWord(word, userId, apiKey) {
  if (!word) {
    return {
      valid: false,
      confidence: 0,
      source: 'master_validation',
      error: 'Missing word',
      signals: []
    };
  }
  
  console.log(`\n🔍 [Master] Validating: "${word}"`);
  
  const signals = [];
  const startTime = Date.now();
  
  try {
    // =========================================================================
    // PHASE 1: FREE SIGNALS (No API cost, fast)
    // =========================================================================
    
    // Signal 1: Crowd Validation (free, 20-50ms)
    console.log('  📊 Running Signal 1: Crowd validation...');
    const crowdResult = await validateByCrowd(word);
    signals.push({ name: 'crowd', ...crowdResult });
    
    // Early exit: Strong crowd signal (10+ users)
    if (crowdResult.confidence >= 0.95) {
      console.log(`  ✅ [Master] Early exit: Strong crowd signal (${crowdResult.confidence})`);
      return {
        valid: true,
        confidence: crowdResult.confidence,
        source: 'crowd_strong',
        word: word,
        signals: signals,
        validationTime: Date.now() - startTime
      };
    }
    
    // Signal 2: Pattern Validation (free, <1ms)
    console.log('  🔤 Running Signal 2: Pattern validation...');
    const patternResult = validateByPatterns(word);
    signals.push({ name: 'patterns', ...patternResult });
    
    // Early exit: Pattern rejection (obvious gibberish)
    if (!patternResult.valid && patternResult.confidence < 0.5) {
      console.log(`  ❌ [Master] Early exit: Failed pattern validation (${patternResult.confidence.toFixed(2)})`);
      return {
        valid: false,
        confidence: patternResult.confidence,
        source: 'patterns_rejected',
        word: word,
        signals: signals,
        validationTime: Date.now() - startTime
      };
    }
    
    // =========================================================================
    // PHASE 2: PRIMARY AI SIGNAL (Fast, accurate, low cost)
    // =========================================================================
    
    // Check if we have API key for paid signals
    if (!apiKey) {
      console.log('  ⚠️ [Master] No API key - using free signals only');
      
      // Combine free signals
      const combinedConfidence = (crowdResult.confidence * 0.6 + patternResult.confidence * 0.4);
      const finalValid = combinedConfidence >= 0.60;
      
      return {
        valid: finalValid,
        confidence: combinedConfidence,
        source: 'free_signals_only',
        word: word,
        signals: signals,
        validationTime: Date.now() - startTime
      };
    }
    
    // Signal 3: GPT Validation (paid, 500-2000ms, accurate)
    console.log('  🤖 Running Signal 3: GPT validation...');
    const gptResult = await validateByGPT(word, apiKey);
    signals.push({ name: 'gpt', ...gptResult });
    
    // Early exit: High confidence GPT result
    if (gptResult.confidence >= 0.85 && gptResult.valid) {
      console.log(`  ✅ [Master] Early exit: GPT validated (${gptResult.confidence})`);
      
      // Boost confidence if crowd and patterns agree
      let finalConfidence = gptResult.confidence;
      if (crowdResult.valid && patternResult.valid) {
        finalConfidence = Math.min(0.98, gptResult.confidence + 0.05);
        console.log(`  📈 [Master] Confidence boosted by agreement: ${finalConfidence.toFixed(2)}`);
      }
      
      return {
        valid: true,
        confidence: finalConfidence,
        source: 'gpt_validated',
        word: word,
        signals: signals,
        validationTime: Date.now() - startTime
      };
    }
    
    // Early exit: GPT rejection with pattern agreement
    if (gptResult.confidence <= 0.20 && !gptResult.valid && !patternResult.valid) {
      console.log(`  ❌ [Master] Early exit: GPT + patterns reject (${gptResult.confidence})`);
      return {
        valid: false,
        confidence: Math.max(gptResult.confidence, patternResult.confidence),
        source: 'gpt_rejected',
        word: word,
        signals: signals,
        validationTime: Date.now() - startTime
      };
    }
    
    // =========================================================================
    // PHASE 3: CROSS-VALIDATION (GPT uncertain, need more signals)
    // =========================================================================
    
    console.log('  🔄 [Master] GPT uncertain, running cross-validation...');
    
    // Signal 4: Translation Round-Trip (paid, 1000-4000ms)
    console.log('  🌐 Running Signal 4: Translation validation...');
    const translationResult = await validateByTranslation(word, apiKey);
    signals.push({ name: 'translation', ...translationResult });
    
    // If translation has high confidence and agrees with GPT, we're done
    if (translationResult.confidence >= 0.85 && translationResult.valid === gptResult.valid) {
      console.log(`  ✅ [Master] Translation confirms GPT (${translationResult.confidence})`);
      
      const avgConfidence = (gptResult.confidence + translationResult.confidence) / 2;
      
      return {
        valid: translationResult.valid,
        confidence: avgConfidence,
        source: 'gpt_translation_agreement',
        word: word,
        signals: signals,
        validationTime: Date.now() - startTime
      };
    }
    
    // =========================================================================
    // PHASE 4: SEMANTIC VALIDATION (Expensive but thorough)
    // =========================================================================
    
    // Only use semantics if we're still uncertain
    console.log('  🧠 Running Signal 5: Semantic validation...');
    const semanticResult = await validateBySemantics(word, apiKey);
    signals.push({ name: 'semantics', ...semanticResult });
    
    // =========================================================================
    // PHASE 5: COMBINE ALL SIGNALS & DECIDE
    // =========================================================================
    
    console.log('  📊 [Master] Combining all signals...');
    
    // Count valid/invalid signals
    let validCount = 0;
    let invalidCount = 0;
    let totalConfidence = 0;
    let weightedConfidence = 0;
    
    const signalWeights = {
      crowd: crowdResult.confidence >= 0.85 ? 0.25 : 0.10,  // Higher weight if strong
      patterns: 0.10,
      gpt: 0.35,          // Highest weight (most reliable)
      translation: 0.25,   // High weight
      semantics: 0.20      // Moderate weight
    };
    
    // Aggregate signals
    if (crowdResult.valid) validCount++;
    else invalidCount++;
    totalConfidence += crowdResult.confidence;
    weightedConfidence += crowdResult.confidence * signalWeights.crowd;
    
    if (patternResult.valid) validCount++;
    else invalidCount++;
    totalConfidence += patternResult.confidence;
    weightedConfidence += patternResult.confidence * signalWeights.patterns;
    
    if (gptResult.valid) validCount++;
    else invalidCount++;
    totalConfidence += gptResult.confidence;
    weightedConfidence += gptResult.confidence * signalWeights.gpt;
    
    if (translationResult.valid) validCount++;
    else invalidCount++;
    totalConfidence += translationResult.confidence;
    weightedConfidence += translationResult.confidence * signalWeights.translation;
    
    if (semanticResult.valid) validCount++;
    else invalidCount++;
    totalConfidence += semanticResult.confidence;
    weightedConfidence += semanticResult.confidence * signalWeights.semantics;
    
    // Normalize weighted confidence
    const totalWeight = Object.values(signalWeights).reduce((sum, w) => sum + w, 0);
    weightedConfidence = weightedConfidence / totalWeight;
    
    const avgConfidence = totalConfidence / 5;
    
    console.log(`  📊 [Master] Results: ${validCount} valid, ${invalidCount} invalid`);
    console.log(`  📊 [Master] Avg confidence: ${avgConfidence.toFixed(2)}, Weighted: ${weightedConfidence.toFixed(2)}`);
    
    // Decision logic: Majority vote with confidence threshold
    const majorityValid = validCount > invalidCount;
    const finalValid = majorityValid && weightedConfidence >= 0.50;
    const finalConfidence = weightedConfidence;
    
    console.log(`  ${finalValid ? '✅' : '❌'} [Master] Final decision: ${finalValid ? 'VALID' : 'INVALID'} (confidence: ${finalConfidence.toFixed(2)})`);
    
    return {
      valid: finalValid,
      confidence: finalConfidence,
      source: 'master_validation',
      word: word,
      signals: signals,
      validationTime: Date.now() - startTime,
      stats: {
        validCount: validCount,
        invalidCount: invalidCount,
        avgConfidence: avgConfidence,
        weightedConfidence: weightedConfidence
      }
    };
    
  } catch (error) {
    console.error(`❌ [Master] Error validating "${word}": ${error.message}`);
    
    // Return best effort result based on signals collected so far
    const validSignals = signals.filter(s => s.valid);
    const avgConfidence = signals.length > 0
      ? signals.reduce((sum, s) => sum + (s.confidence || 0), 0) / signals.length
      : 0;
    
    return {
      valid: validSignals.length > signals.length / 2,
      confidence: avgConfidence,
      source: 'master_validation_error',
      word: word,
      signals: signals,
      validationTime: Date.now() - startTime,
      error: error.message
    };
  }
}

/**
 * Batch validate multiple words efficiently
 * Uses master validation with optimizations for batch processing
 * 
 * @param {Array<string>} words - Array of Georgian words to validate
 * @param {string} userId - User ID
 * @param {string} apiKey - OpenAI API key
 * @returns {Promise<Array<Object>>} Array of validation results
 */
async function batchValidateWords(words, userId, apiKey) {
  if (!words || words.length === 0) {
    return [];
  }
  
  console.log(`\n📦 [Batch] Validating ${words.length} words...`);
  
  const results = [];
  
  // Process words sequentially to avoid rate limiting
  // Could be parallelized with rate limiting in future
  for (const word of words) {
    try {
      const result = await validateGeorgianWord(word, userId, apiKey);
      results.push(result);
      
      // Small delay to avoid rate limiting
      if (words.length > 10) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
      
    } catch (error) {
      console.error(`❌ [Batch] Error validating "${word}": ${error.message}`);
      results.push({
        valid: false,
        confidence: 0,
        source: 'batch_error',
        word: word,
        error: error.message
      });
    }
  }
  
  console.log(`📦 [Batch] Complete: ${results.filter(r => r.valid).length}/${results.length} valid`);
  
  return results;
}

// ============================================================================
// Exports
// ============================================================================

module.exports = {
  // PR1 exports
  trackWordUsage,
  getWordStats,
  
  // PR2 exports
  validateByCrowd,
  validateByPatterns,
  isGeorgianVowel,
  isGeorgianConsonant,
  
  // PR3 exports
  validateByGPT,
  validateByTranslation,
  
  // PR4 exports
  validateBySemantics,
  cosineSimilarity,
  clearEmbeddingCache,
  
  // PR5 exports
  validateGeorgianWord,
  batchValidateWords
};

