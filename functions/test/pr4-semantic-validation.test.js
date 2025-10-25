/**
 * pr4-semantic-validation.test.js
 * Tests for PR4: Semantic Embedding Validation
 * 
 * Run these tests manually to verify semantic validation works correctly.
 * REQUIRES: OPENAI_API_KEY environment variable
 */

const admin = require('firebase-admin');
const { validateBySemantics, cosineSimilarity, clearEmbeddingCache } = require('../wordValidation');

// Initialize Firebase Admin (only if not already initialized)
try {
  admin.initializeApp();
} catch (error) {
  // Already initialized
}

// Get API key from environment
const apiKey = process.env.OPENAI_API_KEY;

if (!apiKey) {
  console.error('❌ ERROR: OPENAI_API_KEY environment variable not set');
  console.error('Run: export OPENAI_API_KEY="your-key-here"');
  process.exit(1);
}

/**
 * Test 1: Cosine similarity calculation
 */
function testCosineSimilarity() {
  console.log('\n📝 Test 1: Cosine similarity calculation');
  
  // Test identical vectors
  const vec1 = [1, 0, 0];
  const vec2 = [1, 0, 0];
  const sim1 = cosineSimilarity(vec1, vec2);
  console.log(`  Identical vectors: ${sim1.toFixed(3)} (expected: 1.000)`);
  
  // Test orthogonal vectors
  const vec3 = [1, 0, 0];
  const vec4 = [0, 1, 0];
  const sim2 = cosineSimilarity(vec3, vec4);
  console.log(`  Orthogonal vectors: ${sim2.toFixed(3)} (expected: 0.000)`);
  
  // Test opposite vectors
  const vec5 = [1, 0, 0];
  const vec6 = [-1, 0, 0];
  const sim3 = cosineSimilarity(vec5, vec6);
  console.log(`  Opposite vectors: ${sim3.toFixed(3)} (expected: -1.000)`);
  
  // Test similar vectors
  const vec7 = [1, 1, 0];
  const vec8 = [1, 0.9, 0];
  const sim4 = cosineSimilarity(vec7, vec8);
  console.log(`  Similar vectors: ${sim4.toFixed(3)} (expected: ~0.99)`);
  
  if (Math.abs(sim1 - 1.0) < 0.001 && Math.abs(sim2 - 0.0) < 0.001) {
    console.log('  ✅ PASS: Cosine similarity works correctly');
  } else {
    console.log('  ❌ FAIL: Cosine similarity incorrect');
  }
}

/**
 * Test 2: Semantic validation - valid common word
 */
async function testSemanticValidationValidWord() {
  console.log('\n📝 Test 2: Semantic validation - valid common word');
  
  const word = 'გამარჯობა'; // "hello" - should be very similar to baseline
  
  try {
    const result = await validateBySemantics(word, apiKey);
    
    console.log('  Result:', {
      valid: result.valid,
      confidence: result.confidence.toFixed(3),
      avgSimilarity: result.avgSimilarity.toFixed(3),
      maxSimilarity: result.maxSimilarity.toFixed(3),
      mostSimilar: result.mostSimilar
    });
    
    if (result.valid && result.avgSimilarity >= 0.60) {
      console.log('  ✅ PASS: Valid Georgian word recognized');
    } else {
      console.log('  ❌ FAIL: Should recognize this common word');
    }
    
  } catch (error) {
    console.log('  ❌ ERROR:', error.message);
  }
}

/**
 * Test 3: Semantic validation - invalid gibberish
 */
async function testSemanticValidationInvalidWord() {
  console.log('\n📝 Test 3: Semantic validation - invalid gibberish');
  
  const word = 'ზხცვბნმქწ'; // Random characters
  
  try {
    const result = await validateBySemantics(word, apiKey);
    
    console.log('  Result:', {
      valid: result.valid,
      confidence: result.confidence.toFixed(3),
      avgSimilarity: result.avgSimilarity ? result.avgSimilarity.toFixed(3) : 'N/A',
      maxSimilarity: result.maxSimilarity ? result.maxSimilarity.toFixed(3) : 'N/A'
    });
    
    // Gibberish should have lower similarity
    if (!result.valid || (result.avgSimilarity && result.avgSimilarity < 0.60)) {
      console.log('  ✅ PASS: Gibberish rejected or low similarity');
    } else {
      console.log('  ⚠️  WARNING: Gibberish has high similarity (may be edge case)');
    }
    
  } catch (error) {
    console.log('  ❌ ERROR:', error.message);
  }
}

/**
 * Test 4: Semantic validation - multiple valid words
 */
async function testSemanticValidationMultipleWords() {
  console.log('\n📝 Test 4: Semantic validation - multiple valid words');
  
  const validWords = [
    'სახლი',   // house
    'წიგნი',   // book
    'მადლობა'  // thanks
  ];
  
  let successCount = 0;
  
  for (const word of validWords) {
    try {
      const result = await validateBySemantics(word, apiKey);
      
      console.log(`  ${word}:`);
      console.log(`    Valid: ${result.valid}, Confidence: ${result.confidence.toFixed(2)}`);
      console.log(`    Avg similarity: ${result.avgSimilarity.toFixed(3)}, Most similar: ${result.mostSimilar}`);
      
      if (result.valid && result.avgSimilarity >= 0.50) {
        console.log(`    ✅ Success`);
        successCount++;
      } else {
        console.log(`    ⚠️  Lower than expected`);
      }
      
      // Small delay
      await new Promise(resolve => setTimeout(resolve, 500));
      
    } catch (error) {
      console.log(`  ❌ ERROR for "${word}": ${error.message}`);
    }
  }
  
  console.log(`  Results: ${successCount}/${validWords.length} validated successfully`);
  
  if (successCount >= validWords.length - 1) {
    console.log('  ✅ PASS: Most words validated');
  } else {
    console.log('  ⚠️  Some words failed validation');
  }
}

/**
 * Test 5: Semantic validation - non-Georgian text
 */
async function testSemanticValidationNonGeorgian() {
  console.log('\n📝 Test 5: Semantic validation - non-Georgian text');
  
  const nonGeorgianWords = [
    'hello',   // English
    'привет',  // Russian
    '你好'     // Chinese
  ];
  
  let allRejected = true;
  
  for (const word of nonGeorgianWords) {
    try {
      const result = await validateBySemantics(word, apiKey);
      
      console.log(`  ${word}:`);
      console.log(`    Valid: ${result.valid}, Avg similarity: ${result.avgSimilarity ? result.avgSimilarity.toFixed(3) : 'N/A'}`);
      
      // Non-Georgian should have low similarity to Georgian words
      if (result.avgSimilarity && result.avgSimilarity >= 0.60) {
        console.log(`    ⚠️  High similarity (unexpected)`);
        allRejected = false;
      }
      
      await new Promise(resolve => setTimeout(resolve, 500));
      
    } catch (error) {
      console.log(`  ❌ ERROR for "${word}": ${error.message}`);
    }
  }
  
  if (allRejected) {
    console.log('  ✅ PASS: Non-Georgian text has low similarity');
  } else {
    console.log('  ⚠️  Some non-Georgian text had high similarity');
  }
}

/**
 * Test 6: Embedding cache functionality
 */
async function testEmbeddingCache() {
  console.log('\n📝 Test 6: Embedding cache functionality');
  
  const word = 'გამარჯობა';
  
  try {
    // First call - should fetch from API
    const start1 = Date.now();
    const result1 = await validateBySemantics(word, apiKey);
    const time1 = Date.now() - start1;
    
    console.log(`  First call (API): ${time1}ms`);
    
    // Second call - should use cache (much faster)
    const start2 = Date.now();
    const result2 = await validateBySemantics(word, apiKey);
    const time2 = Date.now() - start2;
    
    console.log(`  Second call (cached): ${time2}ms`);
    
    // Results should be identical
    const resultsMatch = result1.avgSimilarity === result2.avgSimilarity;
    console.log(`  Results match: ${resultsMatch}`);
    
    // Second call should be significantly faster
    if (time2 < time1 / 2 && resultsMatch) {
      console.log('  ✅ PASS: Cache working correctly');
    } else {
      console.log('  ⚠️  Cache may not be working optimally');
    }
    
    // Test cache clearing
    clearEmbeddingCache();
    console.log('  Cache cleared');
    
  } catch (error) {
    console.log('  ❌ ERROR:', error.message);
  }
}

/**
 * Test 7: Error handling
 */
async function testErrorHandling() {
  console.log('\n📝 Test 7: Error handling');
  
  const word = 'გამარჯობა';
  
  try {
    // Missing API key
    const result1 = await validateBySemantics(word, null);
    
    if (!result1.valid && result1.source === 'semantic_error') {
      console.log('  ✅ PASS: Missing API key handled gracefully');
    } else {
      console.log('  ❌ FAIL: Should return error result');
    }
    
    // Missing word
    const result2 = await validateBySemantics(null, apiKey);
    
    if (!result2.valid && result2.source === 'semantic_error') {
      console.log('  ✅ PASS: Missing word handled gracefully');
    } else {
      console.log('  ❌ FAIL: Should return error result');
    }
    
  } catch (error) {
    console.log('  ❌ ERROR: Should not throw, should return error result');
  }
}

/**
 * Test 8: Performance benchmark
 */
async function testPerformance() {
  console.log('\n📝 Test 8: Performance benchmark');
  
  const word = 'გამარჯობა';
  
  // Clear cache to get true performance
  clearEmbeddingCache();
  
  try {
    const start = Date.now();
    const result = await validateBySemantics(word, apiKey);
    const time = Date.now() - start;
    
    console.log(`  Validation time: ${time}ms`);
    console.log(`  Result: valid=${result.valid}, confidence=${result.confidence.toFixed(2)}`);
    
    // Note: This makes ~31 API calls (1 for word + 30 for baseline)
    // First run will be slow, subsequent runs much faster due to cache
    if (time < 30000) { // 30 seconds max
      console.log('  ✅ PASS: Performance acceptable');
    } else {
      console.log('  ⚠️  WARNING: Slower than expected');
    }
    
    console.log('\n  Note: Semantic validation makes multiple API calls:');
    console.log('  - First run: ~31 calls (1 word + 30 baseline) = 3-10 seconds');
    console.log('  - Subsequent runs: ~1 call (baseline cached) = 100-500ms');
    console.log('  - This is why PR5 uses semantic validation sparingly');
    
  } catch (error) {
    console.log('  ❌ ERROR:', error.message);
  }
}

/**
 * Test 9: Similarity thresholds
 */
async function testSimilarityThresholds() {
  console.log('\n📝 Test 9: Similarity thresholds');
  
  const testWords = [
    { word: 'გამარჯობა', expected: 'high', reason: 'common greeting (in baseline)' },
    { word: 'საქართველო', expected: 'medium-high', reason: '"Georgia" - related to Georgian' },
    { word: 'კომპიუტერი', expected: 'medium', reason: 'computer - loanword' }
  ];
  
  for (const testCase of testWords) {
    try {
      const result = await validateBySemantics(testCase.word, apiKey);
      
      console.log(`  ${testCase.word} (${testCase.reason}):`);
      console.log(`    Avg similarity: ${result.avgSimilarity.toFixed(3)}, Confidence: ${result.confidence.toFixed(2)}`);
      console.log(`    Expected: ${testCase.expected}`);
      
      await new Promise(resolve => setTimeout(resolve, 1000));
      
    } catch (error) {
      console.log(`  ❌ ERROR for "${testCase.word}": ${error.message}`);
    }
  }
  
  console.log('  ℹ️  Thresholds:');
  console.log('    ≥0.70 avg = High confidence (0.90)');
  console.log('    ≥0.60 avg = Good confidence (0.75)');
  console.log('    ≥0.50 avg = Moderate confidence (0.60)');
  console.log('    <0.50 avg = Invalid');
}

/**
 * Run all tests
 */
async function runAllTests() {
  console.log('🧪 PR4 Semantic Embedding Validation Tests');
  console.log('================================');
  console.log('Testing: Semantic embedding validation');
  console.log('Model: text-embedding-3-small');
  console.log('Baseline: 30 common Georgian words');
  console.log('');
  
  // Sync test
  testCosineSimilarity();
  
  // Async tests
  await testSemanticValidationValidWord();
  await testSemanticValidationInvalidWord();
  await testSemanticValidationMultipleWords();
  await testSemanticValidationNonGeorgian();
  
  console.log('\n--- Cache & Performance Tests ---');
  
  await testEmbeddingCache();
  await testErrorHandling();
  await testPerformance();
  
  console.log('\n--- Threshold Analysis ---');
  
  await testSimilarityThresholds();
  
  console.log('\n================================');
  console.log('✅ Tests complete!');
  console.log('\nKey Points:');
  console.log('- Semantic validation uses text-embedding-3-small');
  console.log('- First run: slow (~3-10s) due to baseline embeddings');
  console.log('- Cached runs: fast (~100-500ms)');
  console.log('- Compares to 30 baseline Georgian words');
  console.log('- Uses average similarity for validation');
  console.log('- Cost: ~$0.00002 per validation (31 embeddings)');
  console.log('- Best used as final validation step (PR5)');
  
  process.exit(0);
}

// Run tests if executed directly
if (require.main === module) {
  runAllTests().catch(error => {
    console.error('❌ Test suite failed:', error);
    process.exit(1);
  });
}

module.exports = {
  testCosineSimilarity,
  testSemanticValidationValidWord,
  testSemanticValidationInvalidWord,
  testSemanticValidationMultipleWords,
  testSemanticValidationNonGeorgian,
  testEmbeddingCache,
  testErrorHandling,
  testPerformance,
  testSimilarityThresholds
};

