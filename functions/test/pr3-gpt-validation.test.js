/**
 * pr3-gpt-validation.test.js
 * Tests for PR3: GPT-Based Validation Signals
 * 
 * Run these tests manually to verify GPT validation functions work correctly.
 * REQUIRES: OPENAI_API_KEY environment variable
 */

const admin = require('firebase-admin');
const { validateByGPT, validateByTranslation } = require('../wordValidation');

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
 * Test 1: GPT validation - valid common word
 */
async function testGPTValidationValidWord() {
  console.log('\n📝 Test 1: GPT validation - valid common word');
  
  const word = 'გამარჯობა'; // "hello" - definitely valid
  
  try {
    const result = await validateByGPT(word, apiKey);
    
    console.log('  Result:', result);
    
    if (result.valid && result.confidence >= 0.80) {
      console.log('  ✅ PASS: GPT recognized valid word');
    } else {
      console.log('  ❌ FAIL: GPT should recognize this common word');
    }
    
  } catch (error) {
    console.log('  ❌ ERROR:', error.message);
  }
}

/**
 * Test 2: GPT validation - invalid gibberish
 */
async function testGPTValidationInvalidWord() {
  console.log('\n📝 Test 2: GPT validation - invalid gibberish');
  
  const word = 'ასდფგჰჯკლ'; // Random characters - definitely invalid
  
  try {
    const result = await validateByGPT(word, apiKey);
    
    console.log('  Result:', result);
    
    if (!result.valid || result.confidence <= 0.20) {
      console.log('  ✅ PASS: GPT rejected gibberish');
    } else {
      console.log('  ⚠️  WARNING: GPT accepted gibberish (may be a fluke)');
    }
    
  } catch (error) {
    console.log('  ❌ ERROR:', error.message);
  }
}

/**
 * Test 3: GPT validation - multiple valid words
 */
async function testGPTValidationMultipleWords() {
  console.log('\n📝 Test 3: GPT validation - multiple valid words');
  
  const validWords = [
    'სახლი',   // house
    'წიგნი',   // book
    'მადლობა'  // thanks
  ];
  
  let allPassed = true;
  
  for (const word of validWords) {
    try {
      const result = await validateByGPT(word, apiKey);
      console.log(`  ${word}: valid=${result.valid}, confidence=${result.confidence.toFixed(2)}`);
      
      if (!result.valid) {
        console.log(`    ❌ Should be valid`);
        allPassed = false;
      }
      
      // Small delay to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 500));
      
    } catch (error) {
      console.log(`  ❌ ERROR for "${word}": ${error.message}`);
      allPassed = false;
    }
  }
  
  if (allPassed) {
    console.log('  ✅ PASS: All valid words recognized');
  } else {
    console.log('  ❌ FAIL: Some valid words not recognized');
  }
}

/**
 * Test 4: Translation round-trip - valid word
 */
async function testTranslationValidWord() {
  console.log('\n📝 Test 4: Translation round-trip - valid word');
  
  const word = 'გამარჯობა'; // "hello"
  
  try {
    const result = await validateByTranslation(word, apiKey);
    
    console.log('  Result:', result);
    console.log(`  Translation path: ${word} → ${result.translation} → ${result.roundTrip}`);
    
    if (result.valid && result.confidence >= 0.70) {
      console.log('  ✅ PASS: Round-trip successful');
    } else {
      console.log('  ⚠️  WARNING: Round-trip failed (may be translation variation)');
      console.log('  This can happen with synonyms or alternate spellings');
    }
    
  } catch (error) {
    console.log('  ❌ ERROR:', error.message);
  }
}

/**
 * Test 5: Translation round-trip - invalid word
 */
async function testTranslationInvalidWord() {
  console.log('\n📝 Test 5: Translation round-trip - invalid word');
  
  const word = 'ზხცვბნმ'; // Gibberish
  
  try {
    const result = await validateByTranslation(word, apiKey);
    
    console.log('  Result:', result);
    
    if (result.translation) {
      console.log(`  Translation path: ${word} → ${result.translation} → ${result.roundTrip || 'N/A'}`);
    }
    
    if (!result.valid || result.confidence <= 0.30) {
      console.log('  ✅ PASS: Round-trip rejected invalid word');
    } else {
      console.log('  ⚠️  WARNING: Round-trip accepted invalid word');
      console.log('  GPT may have hallucinated a translation');
    }
    
  } catch (error) {
    console.log('  ❌ ERROR:', error.message);
  }
}

/**
 * Test 6: Translation round-trip - multiple words
 */
async function testTranslationMultipleWords() {
  console.log('\n📝 Test 6: Translation round-trip - multiple words');
  
  const testWords = [
    { word: 'სახლი', expectedEnglish: 'house' },
    { word: 'წიგნი', expectedEnglish: 'book' },
    { word: 'მანქანა', expectedEnglish: 'car' }
  ];
  
  let successCount = 0;
  
  for (const testCase of testWords) {
    try {
      const result = await validateByTranslation(testCase.word, apiKey);
      
      const translationMatches = result.translation && 
        result.translation.toLowerCase().includes(testCase.expectedEnglish.toLowerCase());
      
      console.log(`  ${testCase.word}:`);
      console.log(`    Translation: ${result.translation} (expected: ${testCase.expectedEnglish})`);
      console.log(`    Round-trip: ${result.roundTrip}`);
      console.log(`    Valid: ${result.valid}, Confidence: ${result.confidence.toFixed(2)}`);
      
      if (result.valid && translationMatches) {
        console.log(`    ✅ Success`);
        successCount++;
      } else {
        console.log(`    ⚠️  Partial success or failure`);
      }
      
      // Delay to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 1000));
      
    } catch (error) {
      console.log(`  ❌ ERROR for "${testCase.word}": ${error.message}`);
    }
  }
  
  console.log(`  Results: ${successCount}/${testWords.length} successful`);
  
  if (successCount >= testWords.length - 1) {
    console.log('  ✅ PASS: Most translations successful');
  } else {
    console.log('  ⚠️  Some translations failed');
  }
}

/**
 * Test 7: Error handling - missing API key
 */
async function testErrorHandling() {
  console.log('\n📝 Test 7: Error handling - missing API key');
  
  const word = 'გამარჯობა';
  
  try {
    const result1 = await validateByGPT(word, null);
    const result2 = await validateByTranslation(word, null);
    
    if (!result1.valid && result1.source === 'gpt_error' &&
        !result2.valid && result2.source === 'translation_error') {
      console.log('  ✅ PASS: Errors handled gracefully');
    } else {
      console.log('  ❌ FAIL: Should return error results');
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
  
  try {
    // Test GPT validation speed
    const gptStart = Date.now();
    await validateByGPT(word, apiKey);
    const gptTime = Date.now() - gptStart;
    
    console.log(`  GPT validation: ${gptTime}ms`);
    
    // Small delay
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Test translation round-trip speed (2 API calls)
    const translationStart = Date.now();
    await validateByTranslation(word, apiKey);
    const translationTime = Date.now() - translationStart;
    
    console.log(`  Translation round-trip: ${translationTime}ms`);
    
    if (gptTime < 5000 && translationTime < 10000) {
      console.log('  ✅ PASS: Performance within acceptable range');
    } else {
      console.log('  ⚠️  WARNING: Slower than expected (may be network)');
    }
    
    console.log(`  Note: GPT typically 500-2000ms, Translation 1000-4000ms`);
    
  } catch (error) {
    console.log('  ❌ ERROR:', error.message);
  }
}

/**
 * Run all tests
 */
async function runAllTests() {
  console.log('🧪 PR3 GPT Validation Tests');
  console.log('================================');
  console.log('Testing: GPT validation + Translation round-trip');
  console.log('Model: gpt-4o-mini');
  console.log('');
  
  await testGPTValidationValidWord();
  await testGPTValidationInvalidWord();
  await testGPTValidationMultipleWords();
  
  console.log('\n--- Translation Round-Trip Tests ---');
  
  await testTranslationValidWord();
  await testTranslationInvalidWord();
  await testTranslationMultipleWords();
  
  console.log('\n--- Error Handling & Performance ---');
  
  await testErrorHandling();
  await testPerformance();
  
  console.log('\n================================');
  console.log('✅ Tests complete!');
  console.log('\nKey Points:');
  console.log('- GPT validation: 1 API call per word (~500-2000ms)');
  console.log('- Translation round-trip: 2 API calls per word (~1000-4000ms)');
  console.log('- Both handle errors gracefully (return confidence 0)');
  console.log('- GPT confidence: 0.85 for valid, 0.15 for invalid');
  console.log('- Translation confidence: 0.90 (exact match), 0.70 (close match), 0.20 (no match)');
  console.log('\nNote: Some tests may show warnings - this is normal as GPT is not 100% accurate');
  
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
  testGPTValidationValidWord,
  testGPTValidationInvalidWord,
  testGPTValidationMultipleWords,
  testTranslationValidWord,
  testTranslationInvalidWord,
  testTranslationMultipleWords,
  testErrorHandling,
  testPerformance
};

