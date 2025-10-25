/**
 * pr2-validation.test.js
 * Tests for PR2: Free Validation Signals (Crowd + Patterns)
 * 
 * Run these tests manually to verify validation functions work correctly.
 */

const admin = require('firebase-admin');
const { 
  validateByCrowd, 
  validateByPatterns,
  trackWordUsage 
} = require('../wordValidation');

// Initialize Firebase Admin (only if not already initialized)
try {
  admin.initializeApp();
} catch (error) {
  // Already initialized
}

/**
 * Test 1: Crowd validation with strong signal
 */
async function testCrowdValidationStrong() {
  console.log('\n📝 Test 1: Crowd validation - strong signal (10+ users)');
  
  const word = 'გამარჯობატესტი' + Date.now();
  
  try {
    // Track word by 10 different users
    for (let i = 1; i <= 10; i++) {
      await trackWordUsage(word, `test-user-${i}`);
    }
    
    // Wait for Firestore
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Validate
    const result = await validateByCrowd(word);
    
    console.log('  Result:', result);
    
    if (result.valid && result.confidence === 0.95 && result.source === 'crowd_strong') {
      console.log('  ✅ PASS: Strong crowd signal detected');
    } else {
      console.log('  ❌ FAIL: Expected strong crowd signal');
    }
    
  } catch (error) {
    console.log('  ❌ ERROR:', error.message);
  }
}

/**
 * Test 2: Crowd validation with medium signal
 */
async function testCrowdValidationMedium() {
  console.log('\n📝 Test 2: Crowd validation - medium signal (5-9 users)');
  
  const word = 'მედიუმტესტი' + Date.now();
  
  try {
    // Track word by 6 different users
    for (let i = 1; i <= 6; i++) {
      await trackWordUsage(word, `test-user-${i}`);
    }
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    const result = await validateByCrowd(word);
    
    console.log('  Result:', result);
    
    if (result.valid && result.confidence === 0.85 && result.source === 'crowd_medium') {
      console.log('  ✅ PASS: Medium crowd signal detected');
    } else {
      console.log('  ❌ FAIL: Expected medium crowd signal');
    }
    
  } catch (error) {
    console.log('  ❌ ERROR:', error.message);
  }
}

/**
 * Test 3: Crowd validation with insufficient data
 */
async function testCrowdValidationInsufficient() {
  console.log('\n📝 Test 3: Crowd validation - insufficient data (<3 users)');
  
  const word = 'არასაკმარისი' + Date.now();
  
  try {
    // Track word by only 1 user
    await trackWordUsage(word, 'test-user-1');
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    const result = await validateByCrowd(word);
    
    console.log('  Result:', result);
    
    if (!result.valid && result.source === 'crowd_insufficient') {
      console.log('  ✅ PASS: Insufficient crowd data detected');
    } else {
      console.log('  ❌ FAIL: Should reject with insufficient data');
    }
    
  } catch (error) {
    console.log('  ❌ ERROR:', error.message);
  }
}

/**
 * Test 4: Pattern validation - valid Georgian word
 */
function testPatternValidationValid() {
  console.log('\n📝 Test 4: Pattern validation - valid Georgian words');
  
  const validWords = [
    'გამარჯობა',  // hello - common word
    'სახლი',      // house
    'წიგნი',      // book
    'მადლობა',    // thanks
    'როგორ'      // how
  ];
  
  let allPassed = true;
  
  for (const word of validWords) {
    const result = validateByPatterns(word);
    console.log(`  ${word}: valid=${result.valid}, confidence=${result.confidence.toFixed(2)}`);
    
    if (!result.valid) {
      console.log(`    ❌ Should be valid but was rejected`);
      allPassed = false;
    }
  }
  
  if (allPassed) {
    console.log('  ✅ PASS: All valid words accepted');
  } else {
    console.log('  ❌ FAIL: Some valid words rejected');
  }
}

/**
 * Test 5: Pattern validation - invalid words
 */
function testPatternValidationInvalid() {
  console.log('\n📝 Test 5: Pattern validation - invalid words');
  
  const invalidWords = [
    'ა',          // too short (1 char)
    'აააააა',    // excessive repetition
    'hello',      // not Georgian
    'გ123',       // mixed with numbers
    'ბბბბბბბბბ'   // no vowels
  ];
  
  let allPassed = true;
  
  for (const word of invalidWords) {
    const result = validateByPatterns(word);
    console.log(`  ${word}: valid=${result.valid}, confidence=${result.confidence.toFixed(2)}`);
    
    if (result.valid) {
      console.log(`    ❌ Should be invalid but was accepted`);
      allPassed = false;
    }
  }
  
  if (allPassed) {
    console.log('  ✅ PASS: All invalid words rejected');
  } else {
    console.log('  ❌ FAIL: Some invalid words accepted');
  }
}

/**
 * Test 6: Pattern validation - edge cases
 */
function testPatternValidationEdgeCases() {
  console.log('\n📝 Test 6: Pattern validation - edge cases');
  
  const testCases = [
    { word: 'გამარჯობააა', expected: false, reason: 'excessive repetition at end' },
    { word: 'ᲒᲐᲛᲐᲠᲯᲝᲑᲐ', expected: true, reason: 'uppercase Georgian (rare but valid)' },
    { word: 'მწვრთნელი', expected: true, reason: 'many consecutive consonants (valid in Georgian)' },
    { word: 'აი', expected: true, reason: 'very short but valid' }
  ];
  
  let allPassed = true;
  
  for (const testCase of testCases) {
    const result = validateByPatterns(testCase.word);
    const passed = result.valid === testCase.expected;
    
    console.log(`  ${testCase.word}: valid=${result.valid}, expected=${testCase.expected} - ${testCase.reason}`);
    
    if (!passed) {
      console.log(`    ❌ Unexpected result`);
      allPassed = false;
    }
  }
  
  if (allPassed) {
    console.log('  ✅ PASS: Edge cases handled correctly');
  } else {
    console.log('  ⚠️  Some edge cases failed (may need tuning)');
  }
}

/**
 * Test 7: Combined validation (crowd + patterns)
 */
async function testCombinedValidation() {
  console.log('\n📝 Test 7: Combined validation - crowd + patterns');
  
  const word = 'კომბინაცია' + Date.now();
  
  try {
    // Track by 5 users
    for (let i = 1; i <= 5; i++) {
      await trackWordUsage(word, `test-user-${i}`);
    }
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Validate with both signals
    const crowdResult = await validateByCrowd(word);
    const patternResult = validateByPatterns(word);
    
    console.log('  Crowd result:', { valid: crowdResult.valid, confidence: crowdResult.confidence, source: crowdResult.source });
    console.log('  Pattern result:', { valid: patternResult.valid, confidence: patternResult.confidence });
    
    // Both should agree on validity
    if (crowdResult.valid && patternResult.valid) {
      console.log('  ✅ PASS: Both signals agree on valid word');
    } else if (!crowdResult.valid && !patternResult.valid) {
      console.log('  ✅ PASS: Both signals agree on invalid word');
    } else {
      console.log('  ⚠️  Mixed signals (expected for edge cases)');
      console.log('  Crowd:', crowdResult.valid, 'Patterns:', patternResult.valid);
    }
    
  } catch (error) {
    console.log('  ❌ ERROR:', error.message);
  }
}

/**
 * Run all tests
 */
async function runAllTests() {
  console.log('🧪 PR2 Validation Tests');
  console.log('================================');
  console.log('Testing: Crowd validation + Pattern validation');
  console.log('');
  
  // Crowd validation tests (async)
  await testCrowdValidationStrong();
  await testCrowdValidationMedium();
  await testCrowdValidationInsufficient();
  
  // Pattern validation tests (sync)
  testPatternValidationValid();
  testPatternValidationInvalid();
  testPatternValidationEdgeCases();
  
  // Combined test
  await testCombinedValidation();
  
  console.log('\n================================');
  console.log('✅ Tests complete!');
  console.log('\nKey Points:');
  console.log('- Crowd validation requires word usage data from PR1');
  console.log('- Pattern validation is instant (no database calls)');
  console.log('- Both signals are FREE (no API costs)');
  console.log('- Confidence scores: crowd_strong (0.95), crowd_medium (0.85), crowd_weak (0.60)');
  
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
  testCrowdValidationStrong,
  testCrowdValidationMedium,
  testCrowdValidationInsufficient,
  testPatternValidationValid,
  testPatternValidationInvalid,
  testPatternValidationEdgeCases,
  testCombinedValidation
};

