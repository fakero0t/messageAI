# Learning Feature Upgrade - Task List

## Overview

This document breaks down the implementation of the 5-signal automated word validation system into 7 sequential pull requests. Each PR builds on the previous one to create a robust, self-improving validation system that ensures only legitimate Georgian words (formal and slang) are used in practice questions.

## Goals

- Achieve 95%+ accuracy in word validation
- Support both dictionary words and common slang
- Zero human intervention required
- Self-improving through crowd wisdom
- Maintain fast performance (<200ms average validation)
- Keep practice generation under 8 seconds total

---

## Setup Instructions

### Prerequisites

- Firebase project with Firestore enabled
- OpenAI API access (already configured)
- Node.js environment for Firebase Functions

### Initial Configuration

No additional environment variables needed - reuses existing OpenAI configuration.

### Database Preparation

Before starting PR1, ensure:
- Firestore is enabled in Firebase Console
- Composite indexes can be created (may require Firebase Blaze plan)

### Cold Start Pre-Population

To handle new users with no chat history, pre-populate cache with 1000 common Georgian words:

**Create script: `functions/scripts/seedCommonWords.js`**

```javascript
const admin = require('firebase-admin');
const { validateGeorgianWord } = require('../wordValidation');

// 1000 most common Georgian words (manually curated or from word frequency list)
const COMMON_GEORGIAN_WORDS = [
  'გამარჯობა', 'მადლობა', 'ნახვამდის', 'სახლი', 'წიგნი',
  // ... add 995 more common words
];

async function seedCache() {
  for (const word of COMMON_GEORGIAN_WORDS) {
    const result = await validateGeorgianWord(word, 'system', apiKey);
    await cacheValidationResult(word, result);
    console.log(`Seeded: ${word}`);
  }
}

seedCache();
```

**Run once after PR0 is deployed:**
```bash
cd functions
node scripts/seedCommonWords.js
```

**This ensures:**
- New users have validated words available immediately
- Practice works even with minimal chat history
- Cache hit rate starts at ~70% instead of 0%

---

## PR0: Async Message Validation Hook (Performance Critical)

### Description

Add background word validation when users send messages. This ensures all words are pre-validated before practice generation, keeping practice generation under 8 seconds total.

### Goals

- Validate Georgian words asynchronously when messages are sent
- Store validation results in cache for instant lookup
- Zero impact on message sending latency (runs in background)
- Enable fast practice generation (<8s total)

### Files to Modify

**`functions/index.js`** (or create new `functions/messageHooks.js`)

### Function Signatures & Key Logic

```javascript
/**
 * Firestore trigger: Validate Georgian words when message is created
 * Runs in background, doesn't block message delivery
 */
exports.onMessageCreated = functions.firestore
  .document('messages/{messageId}')
  .onCreate(async (snap, context) => {
    // Key logic:
    // 1. Get message data
    // 2. Check if message contains Georgian text
    // 3. Extract Georgian words (split by whitespace/punctuation)
    // 4. For each word:
    //    - Check if already validated (in wordValidationCache)
    //    - If not cached, call validateGeorgianWord()
    //    - Store result in cache
    // 5. Track word usage (for crowd signal)
    // 6. Log validation metrics
    // 
    // NOTE: This runs async, doesn't block message sending
    // If validation fails/times out, practice will fall back to basic heuristics
  });
```

```javascript
/**
 * Store word validation result in cache
 * @param {string} word - Georgian word
 * @param {Object} validationResult - Result from validateGeorgianWord()
 * @returns {Promise<void>}
 */
async function cacheValidationResult(word, validationResult)

// Key logic:
// - Store in Firestore collection: wordValidationCache
// - Include: word, valid, confidence, source, signals, timestamp
// - TTL: 30 days (auto-cleanup old entries)
```

```javascript
/**
 * Get cached validation result
 * @param {string} word - Georgian word
 * @returns {Promise<Object|null>} Cached result or null
 */
async function getCachedValidation(word)

// Key logic:
// - Query wordValidationCache collection
// - Check if result is still fresh (< 30 days old)
// - Return cached result or null if expired/not found
```

### Database Schema

**Collection: `wordValidationCache`**
```
Document ID: {normalized_word}
Fields:
  - word: string
  - valid: boolean
  - confidence: number (0-1)
  - source: string ('multi_signal', 'crowd_strong', etc.)
  - signals: array<Object> (breakdown of all signal results)
  - timestamp: timestamp (when validated)
  - expiresAt: timestamp (timestamp + 30 days, for auto-cleanup)
  - userId: string (who triggered validation)
```

**Auto-Cleanup Strategy:**

Use Firestore TTL (Time-To-Live) policy to auto-delete old entries:

1. Set `expiresAt` field when creating cache entry:
```javascript
expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 30 * 24 * 60 * 60 * 1000)
```

2. Enable Firestore TTL in Firebase Console:
   - Go to Firestore → Settings → Time-to-live
   - Add TTL policy for `wordValidationCache` collection
   - Field: `expiresAt`
   - Auto-delete after expiration

**Note:** Firestore automatically deletes expired documents (may take 24-72 hours after expiration)

### Firebase Security Rules

Add to `firestore.rules`:

```
// Word validation cache - read by Cloud Functions, write by Cloud Functions only
match /wordValidationCache/{wordId} {
  allow read: if request.auth != null;
  allow write: if false; // Only Cloud Functions
}
```

### Integration Points

- Triggered by Firestore onCreate event (automatic)
- Calls `validateGeorgianWord()` from wordValidation.js (requires PR1-PR5 first)
- Stores results for practice function to use (PR7)
- No changes to client code needed

### Rate Limiting

Add rate limiting to prevent excessive validation calls:

```javascript
/**
 * Rate limit validation per user
 * Limit: 50 words validated per user per minute
 */
const VALIDATION_RATE_LIMIT = 50; // words per minute per user
const userValidationCounts = new Map(); // In-memory counter

async function checkValidationRateLimit(userId) {
  const now = Date.now();
  const key = `${userId}_${Math.floor(now / 60000)}`; // per minute
  
  const count = userValidationCounts.get(key) || 0;
  if (count >= VALIDATION_RATE_LIMIT) {
    console.log(`⚠️ Rate limit hit for user ${userId}`);
    return false; // Skip validation
  }
  
  userValidationCounts.set(key, count + 1);
  return true;
}
```

### Error Handling

If validation fails (OpenAI timeout, error, etc.):
- Log error to Cloud Functions logs
- Skip the word (exclude from practice)
- Continue processing other words
- No retries (keeps message sending fast)

```javascript
try {
  const result = await validateGeorgianWord(word, userId, apiKey);
  await cacheValidationResult(word, result);
} catch (error) {
  console.error(`❌ Validation failed for "${word}": ${error.message}`);
  // Skip this word - exclude from practice
  // Don't cache failed validations
}
```

### Setup Instructions

1. Ensure Firestore triggers are enabled in Firebase project
2. Deploy function: `firebase deploy --only functions:onMessageCreated`
3. Test by sending a message with Georgian text
4. Check Firestore Console for wordValidationCache entries
5. Monitor rate limiting in Cloud Functions logs

### Testing

**Integration Test:**
```javascript
// 1. Create test message with Georgian text
await db.collection('messages').add({
  text: 'გამარჯობა როგორ ხარ',
  senderId: 'test-user',
  conversationId: 'test-conv',
  timestamp: Date.now()
});

// 2. Wait 2-3 seconds for trigger to complete

// 3. Check wordValidationCache
const cache1 = await db.collection('wordValidationCache').doc('გამარჯობა').get();
expect(cache1.exists).toBe(true);
expect(cache1.data().valid).toBe(true);

const cache2 = await db.collection('wordValidationCache').doc('როგორ').get();
expect(cache2.exists).toBe(true);
```

**Performance Test:**
```javascript
// Send 100 messages with Georgian words
// Verify:
// - Message sending not slowed down (still <500ms)
// - Validation happens in background
// - Cache fills up over 10-20 seconds
```

### Performance Considerations

- Trigger runs asynchronously (doesn't block message delivery)
- Validation happens in background (2-5s but user doesn't wait)
- Cache fills gradually as users chat
- By practice generation time, most words already cached
- Practice generation overhead: <1s (just cache lookups)

### Performance Guarantee

**Message Sending:**
- No added latency (validation runs async)
- User experience unchanged

**Practice Generation:**
- Word validation: <1s (cache lookups only)
- GPT generation: 3-8s (existing)
- **Total: 4-9s → Under 8s target** ✅

### Rollback Plan

- Disable trigger: Comment out `exports.onMessageCreated`
- Delete wordValidationCache collection
- Remove security rules
- No impact on existing functionality

---

## PR1: Database Foundation & Word Tracking

### Description

Set up the database infrastructure for tracking word usage across users and caching validation results. This forms the foundation for crowd-based validation.

### Goals

- Create Firestore collections for word statistics and validation cache
- Implement word usage tracking
- Add security rules for new collections
- Enable performance indexes

### Files to Create

**`functions/wordValidation.js`** (new file)

### Function Signatures & Key Logic

```javascript
/**
 * Track word usage by a specific user
 * Increments usage count and adds user to unique user list
 * @param {string} word - Georgian word to track
 * @param {string} userId - User ID who used the word
 * @returns {Promise<void>}
 */
async function trackWordUsage(word, userId)

// Key logic:
// - Normalize word (lowercase, trim)
// - Use Firestore atomic operations (increment, arrayUnion)
// - Update: count, userIds array, lastSeen timestamp
// - Create document if doesn't exist (merge: true)
```

```javascript
/**
 * Get word statistics from database
 * @param {string} word - Georgian word to lookup
 * @returns {Promise<Object|null>} Word stats or null if not found
 */
async function getWordStats(word)

// Key logic:
// - Normalize word before lookup
// - Return { count, userIds, lastSeen, firstSeen }
// - Return null if document doesn't exist
```

### Database Schema

**Collection: `wordStats`**
```
Document ID: {normalized_word} (lowercase, trimmed)
Fields:
  - word: string (original case preserved)
  - count: number (total usage count)
  - userIds: array<string> (unique user IDs)
  - firstSeen: timestamp
  - lastSeen: timestamp
```

**Collection: `gptValidations`**
```
Document ID: {normalized_word}
Fields:
  - word: string (original case)
  - valid: boolean
  - confidence: number (0-1)
  - source: string ('gpt')
  - checkedAt: timestamp
  - ttl: number (milliseconds, for cache expiry)
```

### Firestore Indexes

**Composite Index for `wordStats`:**
- Collection: `wordStats`
- Fields: `lastSeen` (Descending), `count` (Descending)
- Used for: Finding frequently used recent words

### Firebase Security Rules

Add to `firestore.rules`:

```
// Word statistics - write only by Cloud Functions
match /wordStats/{wordId} {
  allow read: if request.auth != null;
  allow write: if false; // Only Cloud Functions can write
}

// GPT validations cache - read only for authenticated users
match /gptValidations/{wordId} {
  allow read: if request.auth != null;
  allow write: if false; // Only Cloud Functions can write
}
```

### Setup Instructions

1. Deploy security rules: `firebase deploy --only firestore:rules`
2. Create indexes via Firebase Console or wait for automatic index creation prompts
3. No environment variables needed

### Testing

**Manual Tests:**
1. Call `trackWordUsage('გამარჯობა', 'user1')` multiple times
2. Verify count increments in Firestore Console
3. Call with different userIds, verify userIds array grows
4. Call `getWordStats('გამარჯობა')`, verify returns correct data

**Automated Tests:**
```bash
cd functions
npm test -- wordValidation.test.js
```

### Performance Considerations

- Uses Firestore atomic operations (increment, arrayUnion) for concurrency safety
- Document reads: ~20-50ms
- Document writes: ~50-100ms

### Rollback Plan

- Delete collections: `wordStats`, `gptValidations`
- Remove security rules
- Remove `functions/wordValidation.js`

---

## PR2: Free Validation Signals (Crowd + Patterns)

### Description

Implement the two free validation signals: crowd wisdom (based on user statistics) and linguistic pattern analysis. These provide fast, zero-cost validation.

### Goals

- Implement crowd-based validation with confidence tiers
- Implement Georgian linguistic pattern analysis
- Achieve 75-80% accuracy from free signals alone

### Files to Modify

**`functions/wordValidation.js`**

### Function Signatures & Key Logic

```javascript
/**
 * Validate word based on crowd wisdom
 * @param {string} word - Georgian word to validate
 * @returns {Promise<Object>} { valid, confidence, source, uniqueUsers }
 */
async function validateByCrowd(word)

// Key logic:
// 1. Get word stats from database
// 2. Count unique users: wordStats.userIds.length
// 3. Apply thresholds:
//    - 10+ users → { valid: true, confidence: 0.95, source: 'crowd_strong' }
//    - 5-9 users → { valid: true, confidence: 0.85, source: 'crowd_medium' }
//    - 3-4 users → { valid: true, confidence: 0.60, source: 'crowd_weak' }
//    - <3 users → { valid: false, confidence: 0, source: 'crowd_insufficient' }
// 4. Return validation result
```

```javascript
/**
 * Validate word based on Georgian linguistic patterns
 * @param {string} word - Georgian word to validate
 * @returns {Object} { valid, confidence, source, patterns }
 */
function validateByPatterns(word)

// Key logic:
// 1. Define Georgian vowels: ა, ე, ი, ო, უ
// 2. Define Georgian consonants: all other Georgian letters
// 3. Check patterns:
//    a) Only Georgian characters (U+10A0 to U+10FF)
//    b) Vowel ratio: 15-50% of word
//    c) Max consecutive consonants: ≤6
//    d) No excessive repetition: same char ≤3 times in a row
//    e) Length: 2-20 characters
//    f) Has both vowels AND consonants
// 4. Score: count how many patterns match (6 total)
// 5. Confidence = matches / 6
// 6. Valid if ≥4 patterns match
// 7. Return { valid, confidence, source: 'linguistic_patterns', patterns: {...} }
```

```javascript
/**
 * Helper: Check if character is Georgian vowel
 * @param {string} char - Single character
 * @returns {boolean}
 */
function isGeorgianVowel(char)

// Key logic: return ['ა', 'ე', 'ი', 'ო', 'უ'].includes(char)
```

```javascript
/**
 * Helper: Check if character is Georgian consonant
 * @param {string} char - Single character
 * @returns {boolean}
 */
function isGeorgianConsonant(char)

// Key logic:
// - Check if char is in range U+10A0 to U+10FF
// - AND not a vowel
```

### Integration Points

- Both functions are standalone, no external dependencies except Firestore for crowd validation
- Can be called independently or combined

### Testing

**Unit Tests for Patterns:**
```javascript
// Test cases:
validateByPatterns('გამარჯობა') // → { valid: true, confidence: ~1.0 }
validateByPatterns('ა') // → { valid: false } (too short)
validateByPatterns('აააააა') // → { valid: false } (excessive repetition)
validateByPatterns('bcdefg') // → { valid: false } (not Georgian)
validateByPatterns('გმრთლბლნჯს') // → { valid: false } (no vowels)
```

**Unit Tests for Crowd:**
```javascript
// Setup: Seed wordStats with test data
// Test cases:
validateByCrowd('word_with_10_users') // → { confidence: 0.95 }
validateByCrowd('word_with_5_users') // → { confidence: 0.85 }
validateByCrowd('word_with_2_users') // → { valid: false }
```

### Performance Considerations

- Pattern analysis: <1ms (pure computation)
- Crowd validation: 20-50ms (single Firestore read)
- Combined: ~50ms

### Rollback Plan

- Comment out or remove the two functions
- No database changes needed

---

## PR3: GPT-Based Validation Signals

### Description

Implement validation using GPT-4 and translation round-trip consistency. These signals provide high accuracy at low cost when cached.

### Goals

- Implement GPT yes/no word validation with caching
- Implement translation round-trip consistency check
- Achieve 85-90% accuracy from GPT signals

### Files to Modify

**`functions/wordValidation.js`**

### Function Signatures & Key Logic

```javascript
/**
 * Validate word using GPT-4
 * Checks if GPT recognizes it as a real Georgian word (standard or slang)
 * Results are cached in Firestore for 1 week
 * @param {string} word - Georgian word to validate
 * @param {string} apiKey - OpenAI API key
 * @returns {Promise<Object>} { valid, confidence, source }
 */
async function validateByGPT(word, apiKey)

// Key logic:
// 1. Check cache first (gptValidations collection)
// 2. If cached and not expired (< 7 days old):
//    - Return cached result
// 3. If not cached or expired:
//    - Build prompt: "Is '{word}' a real Georgian word (standard or slang)? Answer only yes or no."
//    - Call GPT-4o-mini with temperature: 0, max_tokens: 5
//    - Parse response (expect "yes" or "no")
//    - Map to validation: yes → { valid: true, confidence: 0.80 }
//                         no → { valid: false, confidence: 0.10 }
//    - Cache result in gptValidations collection
// 4. Return { valid, confidence, source: 'gpt' }
```

```javascript
/**
 * Validate word using translation round-trip consistency
 * Georgian → English → Georgian, check if similar to original
 * @param {string} word - Georgian word to validate
 * @param {string} apiKey - OpenAI API key
 * @returns {Promise<Object>} { valid, confidence, source, english, roundtrip }
 */
async function validateByTranslation(word, apiKey)

// Key logic:
// 1. Check cache first (translationCache collection - reuse existing)
// 2. Translate Georgian → English using GPT-4o-mini
//    - Prompt: "Translate this Georgian word to English: {word}. Reply with only the English word."
// 3. Translate English → Georgian
//    - Prompt: "Translate this English word to Georgian: {english}. Reply with only the Georgian word."
// 4. Calculate similarity between original and roundtrip
//    - Use Levenshtein distance
//    - Similarity = (maxLen - distance) / maxLen
// 5. Valid if similarity ≥ 0.70
// 6. Confidence = similarity score
// 7. Cache both translations
// 8. Return { valid, confidence, source: 'translation_roundtrip', english, roundtrip }
```

```javascript
/**
 * Calculate Levenshtein distance between two strings
 * @param {string} str1 - First string
 * @param {string} str2 - Second string
 * @returns {number} Edit distance
 */
function levenshteinDistance(str1, str2)

// Key logic:
// - Build matrix (str1.length+1 x str2.length+1)
// - Initialize first row/column with indices
// - Fill matrix using dynamic programming:
//   - If chars match: matrix[i][j] = matrix[i-1][j-1]
//   - If chars differ: matrix[i][j] = min(
//       matrix[i-1][j] + 1,    // deletion
//       matrix[i][j-1] + 1,    // insertion
//       matrix[i-1][j-1] + 1   // substitution
//     )
// - Return matrix[str1.length][str2.length]
```

```javascript
/**
 * Helper: Call GPT for simple translation
 * @param {string} text - Text to translate
 * @param {string} targetLang - Target language ('en' or 'ka')
 * @param {string} apiKey - OpenAI API key
 * @returns {Promise<string>} Translated text
 */
async function simpleTranslate(text, targetLang, apiKey)

// Key logic:
// - Build prompt based on targetLang
// - Call GPT-4o-mini
// - Return trimmed response
// - (Can reuse existing translation helpers from index.js if available)
```

### Integration Points

- Reuse OpenAI API key from existing configuration
- Reuse existing translation cache structure if available
- Both functions are standalone but share caching infrastructure

### Testing

**Unit Tests for Levenshtein:**
```javascript
levenshteinDistance('cat', 'cat') // → 0
levenshteinDistance('cat', 'cut') // → 1
levenshteinDistance('cat', 'dog') // → 3
```

**Integration Tests for GPT Validation:**
```javascript
// Real words
await validateByGPT('გამარჯობა', apiKey) // → { valid: true, confidence: 0.80 }
await validateByGPT('სახლი', apiKey) // → { valid: true }

// Gibberish
await validateByGPT('ასდფგ', apiKey) // → { valid: false }
```

**Integration Tests for Translation:**
```javascript
await validateByTranslation('სახლი', apiKey) 
// → { valid: true, confidence: ~0.95, english: 'house', roundtrip: 'სახლი' }

await validateByTranslation('ასდფგ', apiKey)
// → { valid: false, confidence: < 0.40 }
```

### Performance Considerations

- GPT validation (cached): 20ms (Firestore read)
- GPT validation (uncached): 500-1000ms (API call)
- Translation round-trip (cached): 20ms
- Translation round-trip (uncached): 1-2s (2 API calls)
- Cache hit rate target: 60%+ after week 1

### Rollback Plan

- Remove/comment out the three functions
- Clear gptValidations collection if needed
- No security rule changes

---

## PR4: Semantic Embedding Validation

### Description

Implement validation using OpenAI embeddings and semantic similarity. Real Georgian words cluster together in embedding space; random strings don't.

### Goals

- Generate embeddings for candidate words
- Compare to embeddings of verified Georgian words
- Achieve 80% accuracy from semantic signal

### Files to Modify

**`functions/wordValidation.js`**

### Function Signatures & Key Logic

```javascript
/**
 * Validate word using semantic similarity to known Georgian words
 * @param {string} word - Georgian word to validate
 * @param {string} apiKey - OpenAI API key
 * @returns {Promise<Object>} { valid, confidence, source, avgSimilarity }
 */
async function validateBySemantics(word, apiKey)

// Key logic:
// 1. Get embedding for candidate word
// 2. Get embeddings for 100 verified Georgian words (cached)
// 3. Calculate cosine similarity to each verified word
// 4. Average all similarities
// 5. Real Georgian words: avgSimilarity 0.60-0.90
//    Random gibberish: avgSimilarity < 0.40
// 6. Valid if avgSimilarity ≥ 0.50
// 7. Confidence = avgSimilarity
// 8. Return { valid, confidence, source: 'semantic_embedding', avgSimilarity }
```

```javascript
/**
 * Get embedding vector for text using OpenAI
 * @param {string} text - Text to embed
 * @param {string} apiKey - OpenAI API key
 * @returns {Promise<Array<number>>} Embedding vector (1536 dimensions)
 */
async function getEmbedding(text, apiKey)

// Key logic:
// 1. Call OpenAI Embeddings API
//    - Model: 'text-embedding-3-small'
//    - Input: text
// 2. Parse response: data.data[0].embedding
// 3. Return array of floats (1536 dimensions)
// 4. Cache result in Firestore for future use
```

```javascript
/**
 * Calculate cosine similarity between two vectors
 * @param {Array<number>} vecA - First vector
 * @param {Array<number>} vecB - Second vector
 * @returns {number} Similarity score (0-1)
 */
function cosineSimilarity(vecA, vecB)

// Key logic:
// 1. Calculate dot product: sum(vecA[i] * vecB[i])
// 2. Calculate magnitude A: sqrt(sum(vecA[i]^2))
// 3. Calculate magnitude B: sqrt(sum(vecB[i]^2))
// 4. Cosine similarity = dotProduct / (magnitudeA * magnitudeB)
// 5. Return value between -1 and 1 (typically 0-1 for similar texts)
```

```javascript
/**
 * Get cached embeddings for verified Georgian words
 * @returns {Promise<Array<Object>>} Array of { word, embedding }
 */
async function getVerifiedWordEmbeddings()

// Key logic:
// 1. Check if cached in memory or Firestore
// 2. If not cached, generate embeddings for seed list
// 3. Cache for future use
// 4. Return array of { word, embedding } objects
```

### Seed Word List (100 Verified Georgian Words)

Include in code as constant:

```javascript
const VERIFIED_GEORGIAN_WORDS = [
  // Greetings & Basics (10)
  'გამარჯობა', 'გაუმარჯოს', 'ნახვამდის', 'მადლობა', 'გმადლობთ',
  'კი', 'არა', 'დიახ', 'კარგი', 'ცუდი',
  
  // Common Nouns (30)
  'სახლი', 'ბინა', 'ქალაქი', 'ქუჩა', 'მანქანა',
  'წიგნი', 'მაგიდა', 'სკამი', 'ფანჯარა', 'კარი',
  'წყალი', 'საჭმელი', 'პური', 'ყავა', 'ჩაი',
  'ადამიანი', 'კაცი', 'ქალი', 'ბავშვი', 'მეგობარი',
  'დღე', 'ღამე', 'დილა', 'საღამო', 'საათი',
  'ფული', 'სამუშაო', 'სკოლა', 'უნივერსიტეტი', 'ბაღი',
  
  // Common Verbs (30)
  'მიდივარ', 'მოვდივარ', 'წავალ', 'მოვა', 'ვარ',
  'მაქვს', 'მინდა', 'მიყვარს', 'ვიცი', 'მესმის',
  'ვაკეთებ', 'ვწერ', 'ვკითხულობ', 'ვსაუბრობ', 'ვუსმენ',
  'ვჭამ', 'ვსვამ', 'ვიძინებ', 'ვმუშაობ', 'ვსწავლობ',
  'ვხედავ', 'ვფიქრობ', 'ვგრძნობ', 'ვიცინები', 'ვტირი',
  'ვაძლევ', 'ვიღებ', 'ვყიდულობ', 'ვყიდი', 'ვხსნი',
  
  // Pronouns & Question Words (15)
  'მე', 'შენ', 'ის', 'ჩვენ', 'თქვენ', 'ისინი',
  'რა', 'ვინ', 'სად', 'როდის', 'როგორ', 'რატომ', 'რამდენი', 'რომელი', 'ვისი',
  
  // Common Adjectives (15)
  'დიდი', 'პატარა', 'ახალი', 'ძველი', 'ლამაზი',
  'ცხელი', 'ცივი', 'სწრაფი', 'ნელი', 'ძვირი',
  'იაფი', 'ძლიერი', 'სუსტი', 'ახლო', 'შორი'
];
```

### Database Schema

**Collection: `embeddingCache`** (optional, for performance)
```
Document ID: {normalized_word}
Fields:
  - word: string
  - embedding: array<number> (1536 floats)
  - createdAt: timestamp
  - model: string ('text-embedding-3-small')
```

### Setup Instructions

1. No additional configuration needed
2. First run will generate embeddings for 100 verified words (~2-3 seconds)
3. Embeddings are cached for future runs

### Testing

**Unit Tests for Cosine Similarity:**
```javascript
const vec1 = [1, 0, 0];
const vec2 = [1, 0, 0];
cosineSimilarity(vec1, vec2) // → 1.0 (identical)

const vec3 = [0, 1, 0];
cosineSimilarity(vec1, vec3) // → 0.0 (orthogonal)
```

**Integration Tests for Semantic Validation:**
```javascript
// Real Georgian words
await validateBySemantics('გამარჯობა', apiKey) // → { valid: true, confidence: 0.70-0.85 }
await validateBySemantics('სახლი', apiKey) // → { valid: true }

// Gibberish
await validateBySemantics('ასდფგ', apiKey) // → { valid: false, confidence: < 0.40 }
```

### Performance Considerations

- Embedding generation: 200-400ms per word
- Cosine similarity calculation: <1ms per comparison
- 100 comparisons: ~50ms total
- Full validation: 200-500ms (uncached)
- Cache embeddings aggressively

### Rollback Plan

- Remove/comment out functions
- Delete `embeddingCache` collection if created
- Remove VERIFIED_GEORGIAN_WORDS constant

---

## PR5: Master Validation Function

### Description

Combine all 5 signals into a unified validation function with weighted scoring, early exits, and comprehensive logging.

### Goals

- Implement weighted combination of all signals
- Add smart early exit logic
- Achieve 95%+ accuracy
- Comprehensive logging for debugging

### Files to Modify

**`functions/wordValidation.js`**

### Function Signatures & Key Logic

```javascript
/**
 * Master validation function - combines all 5 signals
 * @param {string} word - Georgian word to validate
 * @param {string} userId - User ID (for tracking)
 * @param {string} apiKey - OpenAI API key
 * @returns {Promise<Object>} { valid, confidence, source, signals }
 */
async function validateGeorgianWord(word, userId, apiKey)

// Key logic:
// 1. Initialize results array: signals = []
// 
// 2. Check Signal 1: Crowd (free, fast)
//    - Call validateByCrowd(word)
//    - Push result to signals
//    - EARLY EXIT: If confidence ≥ 0.95, return immediately
//      → { valid: true, confidence: 0.95, source: 'crowd_strong' }
// 
// 3. Check Signal 2: Patterns (free, instant)
//    - Call validateByPatterns(word)
//    - Push result to signals
//    - EARLY REJECTION: If !valid, return immediately
//      → { valid: false, confidence: 0.10, source: 'failed_patterns' }
// 
// 4. Check Signal 3: GPT (moderate cost, cached)
//    - Call validateByGPT(word, apiKey)
//    - Push result to signals
// 
// 5. Check Signal 4: Translation (moderate cost, cached)
//    - Call validateByTranslation(word, apiKey)
//    - Push result to signals
// 
// 6. Calculate average confidence so far
//    - If avgConfidence < 0.70, run Signal 5 (semantic)
//    - Otherwise skip Signal 5 to save cost
// 
// 7. Check Signal 5: Semantic (if needed)
//    - Call validateBySemantics(word, apiKey)
//    - Push result to signals
// 
// 8. Calculate weighted average:
//    - Define weights: {
//        crowd_strong: 1.0,
//        crowd_medium: 0.9,
//        crowd_weak: 0.5,
//        gpt: 0.80,
//        translation_roundtrip: 0.85,
//        linguistic_patterns: 0.60,
//        semantic_embedding: 0.70
//      }
//    - weightedSum = sum(signal.confidence * weight[signal.source])
//    - weightSum = sum(weight[signal.source])
//    - finalConfidence = weightedSum / weightSum
// 
// 9. Make decision:
//    - valid = finalConfidence ≥ 0.65
// 
// 10. If valid, track usage for crowd building:
//     - Call trackWordUsage(word, userId)
// 
// 11. Log comprehensive results:
//     - console.log each signal's contribution
//     - console.log final decision
// 
// 12. Return { valid, confidence: finalConfidence, source: 'multi_signal', signals }
```

```javascript
/**
 * Get signal weight based on source type
 * @param {string} source - Signal source identifier
 * @returns {number} Weight (0-1)
 */
function getSignalWeight(source)

// Key logic:
// - Return appropriate weight for each source type
// - Defaults to 0.5 for unknown sources
```

### Integration Points

- Calls all validation functions from PR2, PR3, PR4
- Uses trackWordUsage from PR1
- Returns comprehensive result object for debugging

### Logging Strategy

Include detailed console logs:
```javascript
console.log(`🔍 Validating word: "${word}"`);
console.log(`  Signal 1 (Crowd): ${crowdResult.confidence.toFixed(2)}`);
console.log(`  Signal 2 (Patterns): ${patternsResult.confidence.toFixed(2)}`);
console.log(`  Signal 3 (GPT): ${gptResult.confidence.toFixed(2)}`);
console.log(`  Signal 4 (Translation): ${translationResult.confidence.toFixed(2)}`);
if (semanticResult) {
  console.log(`  Signal 5 (Semantic): ${semanticResult.confidence.toFixed(2)}`);
}
console.log(`  ✅ Final: ${finalConfidence.toFixed(2)} → ${valid ? 'VALID' : 'INVALID'}`);
```

### Testing

**Integration Tests:**
```javascript
// Real dictionary word
const result1 = await validateGeorgianWord('გამარჯობა', 'user1', apiKey);
// Expected: { valid: true, confidence: 0.85-0.95 }

// Slang word (low crowd initially)
const result2 = await validateGeorgianWord('ზდ', 'user1', apiKey);
// Expected: { valid: true, confidence: 0.65-0.75 }

// Gibberish
const result3 = await validateGeorgianWord('ასდფგ', 'user1', apiKey);
// Expected: { valid: false, confidence: 0.15-0.30 }

// Typo of real word
const result4 = await validateGeorgianWord('გამარჯობააა', 'user1', apiKey);
// Expected: { valid: false, confidence: 0.30-0.50 }
```

**Performance Tests:**
```javascript
// Measure latency for each scenario
// - High crowd word (early exit): < 50ms
// - No crowd, good patterns: 100-500ms
// - Full validation with all signals: 500-2000ms (first time)
// - Cached validation: < 100ms
```

### Performance Considerations

- Early exits reduce average latency significantly
- Cached results make repeated validations very fast
- Skip expensive signals when not needed
- Expected average latency: 100-200ms after cache warm-up

### Rollback Plan

- Remove/comment out master function
- Can still use individual signals directly if needed

---

## PR7: Practice Function Integration (Cache-Only)

### Description

Integrate the validation system into practice generation using ONLY cached results from PR0. This ensures practice stays under 8 seconds by avoiding real-time validation.

### Goals

- Replace `extractValidGeorgianWords()` to use cached validations only
- Fall back to basic heuristics if no cache entry exists
- Update GPT prompts to emphasize word validation
- Add validation metrics logging
- Guarantee <8s total practice generation time

### Files to Modify

**`functions/practiceFunction.js`**

### Function Changes

**Update existing function:**

```javascript
/**
 * Extract and validate Georgian words from text (UPDATED)
 * Uses CACHED validations only (from PR0 message hook)
 * Falls back to basic heuristics if no cache entry
 * @param {string} text - Message text
 * @param {string} userId - User ID who sent the message
 * @returns {Promise<Array<string>>} Array of validated Georgian words
 */
async function extractValidGeorgianWords(text, userId)

// Key logic changes:
// 1. Split text into words (keep existing logic)
// 2. For each word:
//    - Check if basic Georgian script (quick filter)
//    - Look up word in wordValidationCache (from PR0)
//    - If cache hit AND valid: include word
//    - If cache miss: fall back to basic heuristics (existing isValidGeorgianWord)
//    - Log whether cache hit or miss
// 3. Return array of validated words
// 4. Log statistics:
//    - Total words found
//    - Words from cache (hits)
//    - Words from heuristics (misses)
//    - Average confidence (for cached words)
// 
// PERFORMANCE: Only cache lookups (no API calls)
// - Cache hit: ~20ms per word
// - Cache miss: Use existing fast heuristics
// - Total overhead: <1s for typical practice generation
```

**Update existing function:**

```javascript
/**
 * Fetch user's sent messages grouped by conversation (UPDATED)
 * Now passes userId to extraction function
 */
async function fetchUserMessages(userId)

// Key logic changes:
// - Pass userId to extractValidGeorgianWords()
// - Change: extractValidGeorgianWords(data.text, userId)
// - Everything else stays the same
```

**Update existing function:**

```javascript
/**
 * Build conversation summaries for GPT-4 context (UPDATED)
 * Now includes validation confidence in context
 */
async function buildConversationContext(conversations, userId)

// Key logic changes:
// - Pass userId to extractValidGeorgianWords()
// - Optionally include confidence scores in context
// - Keep existing structure
```

### Import Statement

Add to top of `practiceFunction.js`:

```javascript
const { getCachedValidation } = require('./wordValidation');
// OR access cache directly from Firestore if function not exported
```

**Note:** Only need cache lookup function, not the full validation function (that runs in PR0 message hook)

### GPT Prompt Updates

**Update in `generatePersonalizedPractice()`:**

```javascript
const systemPrompt = `You are a Georgian language teacher creating personalized spelling practice for an English speaker learning Georgian.

CONTEXT:
The user has sent the following Georgian words in their conversations.
IMPORTANT: These words have been automatically validated through multiple signals:
- Crowd validation (used by multiple users)
- Linguistic pattern analysis
- GPT verification
- Translation consistency
All words below are VERIFIED as legitimate Georgian (formal or slang):

${contextStr}

TASK:
Generate 15 practice items using ONLY the verified words above.
...
[rest of existing prompt]
`;
```

**Update in `generateGenericPractice()`:**

Add emphasis on word verification:
```javascript
const systemPrompt = `...
Each item should:
- Use ONLY correctly spelled, real Georgian words from standard vocabulary
- NEVER use misspelled, invented, or nonsense words
- All words MUST be verifiable through Georgian dictionaries or common usage
...
[rest of existing prompt]
`;
```

### Validation Metrics Logging

Add new function to track validation performance:

```javascript
/**
 * Log validation metrics for analytics
 * @param {Array<Object>} validationResults - Array of validation results
 */
function logValidationMetrics(validationResults)

// Key logic:
// - Calculate average confidence
// - Count by source (crowd, gpt, translation, etc.)
// - Count valid vs invalid
// - Log to console for Cloud Functions logs
// Example:
//   console.log('📊 [Validation Metrics]', {
//     total: 50,
//     valid: 42,
//     invalid: 8,
//     avgConfidence: 0.87,
//     sources: { crowd_strong: 30, gpt: 10, translation: 2 }
//   });
```

### Integration Points

- Import cache lookup function from `wordValidation.js` (or access Firestore directly)
- Pass userId from `fetchUserMessages()` through extraction chain
- Use cached validations from PR0 (wordValidationCache collection)
- Fall back to existing heuristics if cache miss
- Log validation metrics (cache hit rate, confidence, etc.)

### Testing

**End-to-End Test:**
```javascript
// 1. Seed database with test user messages containing:
//    - Real words: "გამარჯობა", "სახლი"
//    - Slang: "ზდ"
//    - Typos: "გამარჯობააა"
//    - Gibberish: "ასდფგ"

// 2. Call generatePractice for test user

// 3. Verify practice batch:
//    - Contains "გამარჯობა" ✅
//    - Contains "სახლი" ✅
//    - Contains "ზდ" ✅ (if validated by GPT)
//    - Does NOT contain "გამარჯობააა" ❌
//    - Does NOT contain "ასდფგ" ❌

// 4. Check validation metrics logs
//    - Should show breakdown of sources used
//    - Should show high average confidence
```

**Manual Test via Firebase Console:**
```bash
# Deploy function
firebase deploy --only functions:generatePractice

# Test via Firebase Console Functions tab
# Or via curl:
curl -X POST https://your-region-your-project.cloudfunctions.net/generatePractice \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"userId": "test-user-id"}'
```

### Performance Considerations

**CACHE-ONLY APPROACH (PR0 Pre-Validates):**
- Cache lookups only: ~20ms per word, ~50 words = <1s total
- No API calls during practice generation
- Fall back to fast heuristics if cache miss (<1ms per word)
- **Total validation overhead: <1s**

**Practice Generation Timeline:**
- Word extraction & cache lookup: <1s
- GPT practice generation: 3-7s (existing)
- **Total: 4-8s ✅ UNDER 8s TARGET**

**Cache Hit Rate:**
- Week 1: 40-50% (users have some chat history)
- Month 1: 70-80% (most words pre-validated)
- Month 3+: 90%+ (mature system)

### Setup Instructions

1. Ensure all previous PRs are deployed
2. Deploy updated practice function: `firebase deploy --only functions:generatePractice`
3. Test with real user data
4. Monitor Cloud Functions logs for validation metrics

### Rollback Plan

- Revert `extractValidGeorgianWords()` to use basic heuristics only
- Remove cache lookup logic
- Remove import of `getCachedValidation`
- Remove validation metrics logging
- Revert GPT prompt changes
- Keep wordValidationCache (doesn't hurt, PR0 still runs)
- No breaking changes

---

## Success Metrics

### Overall System Performance

After all PRs are complete and system has matured (Month 2+):

**Accuracy:**
- Word validation accuracy: >95%
- Practice questions with invalid words: 0%
- False positive rate (rejecting real words): <5%
- False negative rate (accepting gibberish): <1%

**Performance:**
- Average validation latency: <200ms (for background validation in PR0)
- Practice generation total time: <8s ✅
- Practice validation overhead: <1s (cache lookups only)
- Cache hit rate: >80%
- Crowd-validated words: >70% of total validations

**System Health:**
- No crashes or timeout errors
- Validation logs show clear signal contributions
- Firestore read/write operations within quotas
- OpenAI API usage optimized through caching

### Monitoring Strategy

**Use Cloud Functions Logs Only** (no external monitoring tools):

**Key logs to watch:**
```javascript
// Success logs
"✅ [Validation] Word validated: {word}, confidence: {score}, source: {source}"
"📊 [Metrics] Cache hit rate: {rate}%, avg confidence: {conf}"

// Error logs
"❌ [Validation] Failed for {word}: {error}"
"⚠️ [RateLimit] User {userId} hit rate limit"

// Performance logs
"⚡ [Performance] Practice generation: {time}ms (target: <8000ms)"
"🔍 [Cache] Hit: {hits}, Miss: {misses}, Rate: {percentage}%"
```

**View logs:**
```bash
# View all validation logs
firebase functions:log --only onMessageCreated

# View practice generation logs
firebase functions:log --only generatePractice

# Filter for errors
firebase functions:log | grep "❌"
```

**Health indicators:**
- Cache hit rate >70% (after 1 week)
- Validation success rate >95%
- Practice generation <8s (99th percentile)
- No rate limit warnings for normal users

**Example metrics logged:**
```javascript
{
  "validationMetrics": {
    "timestamp": "2024-10-25T12:00:00Z",
    "totalWords": 150,
    "validWords": 143,
    "invalidWords": 7,
    "avgConfidence": 0.89,
    "sourceBreakdown": {
      "crowd_strong": 85,
      "crowd_medium": 30,
      "gpt": 15,
      "translation": 8,
      "patterns": 5
    },
    "avgLatency": 187,
    "cacheHitRate": 0.82
  }
}
```

---

## Deployment Order

**IMPORTANT:** PR0 must be deployed LAST (after PR1-PR6) because it depends on the validation functions.

1. **PR1**: Deploy database foundation (wordStats, gptValidations collections)
2. **PR2**: Deploy free signals (crowd + patterns validation)
3. **PR3**: Deploy GPT signals (GPT validation + translation round-trip)
4. **PR4**: Deploy semantic signal (embeddings validation)
5. **PR5**: Deploy master validation function (combines all 5 signals)
6. **Wait 24 hours** - Test validation functions work correctly
7. **PR0**: Deploy async message validation hook (starts building cache)
8. **Wait 1 week** - Let cache populate as users chat
9. **PR7**: Integrate cache-only validation with practice function
10. **Monitor** for 1 week, then evaluate metrics

**Why this order?**
- PR0 depends on validateGeorgianWord() from PR5
- PR7 depends on cache from PR0
- Allows testing validation system before integrating with practice
- Cache builds gradually, improving over time

---

## Notes

- All PRs are designed to be backward compatible
- Each PR can be tested independently
- System improves over time as crowd data grows
- No breaking changes to existing practice functionality
- Can be rolled back at any stage
- **PR0 (async validation) is the key to <8s practice generation**
- Cache-only approach in PR7 guarantees fast performance
- Validation happens in background during normal chat usage
- Practice generation never waits for API calls (cache-only)

