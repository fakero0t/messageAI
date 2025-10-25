/**
 * wordValidation.test.js
 * Manual tests for PR1: Word tracking functions
 * 
 * Run these tests manually to verify word tracking works correctly.
 * These are integration tests that require Firebase connection.
 */

const admin = require('firebase-admin');
const { trackWordUsage, getWordStats } = require('../wordValidation');

// Initialize Firebase Admin (only if not already initialized)
try {
  admin.initializeApp();
} catch (error) {
  // Already initialized
}

/**
 * Test 1: Track word usage
 */
async function testTrackWordUsage() {
  console.log('\n📝 Test 1: Track word usage');
  
  const word = 'გამარჯობა';
  const userId1 = 'test-user-1';
  const userId2 = 'test-user-2';
  
  try {
    // Track same word by different users
    await trackWordUsage(word, userId1);
    await trackWordUsage(word, userId1); // Same user again
    await trackWordUsage(word, userId2); // Different user
    
    // Wait for Firestore to update
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Get stats
    const stats = await getWordStats(word);
    
    console.log('  Results:', stats);
    console.log('  Expected count: >=3 (may be higher if tests run multiple times)');
    console.log('  Expected uniqueUsers: >=2');
    
    if (stats && stats.count >= 3) {
      console.log('  ✅ PASS: Count incremented correctly');
    } else {
      console.log('  ❌ FAIL: Count not incremented');
    }
    
    if (stats && stats.uniqueUsers >= 2) {
      console.log('  ✅ PASS: Multiple users tracked');
    } else {
      console.log('  ❌ FAIL: Users not tracked correctly');
    }
    
  } catch (error) {
    console.log('  ❌ ERROR:', error.message);
  }
}

/**
 * Test 2: Get word stats for non-existent word
 */
async function testGetNonExistentWord() {
  console.log('\n📝 Test 2: Get stats for non-existent word');
  
  const word = 'ასდფგჰჯკლ-რანდომ-' + Date.now();
  
  try {
    const stats = await getWordStats(word);
    
    if (stats === null) {
      console.log('  ✅ PASS: Returns null for non-existent word');
    } else {
      console.log('  ❌ FAIL: Should return null');
      console.log('  Got:', stats);
    }
    
  } catch (error) {
    console.log('  ❌ ERROR:', error.message);
  }
}

/**
 * Test 3: Track multiple words
 */
async function testTrackMultipleWords() {
  console.log('\n📝 Test 3: Track multiple words');
  
  const words = ['სახლი', 'წიგნი', 'მანქანა'];
  const userId = 'test-user-3';
  
  try {
    // Track all words
    for (const word of words) {
      await trackWordUsage(word, userId);
    }
    
    // Wait for Firestore
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Verify all were tracked
    let allTracked = true;
    for (const word of words) {
      const stats = await getWordStats(word);
      if (!stats || stats.count < 1) {
        allTracked = false;
        console.log(`  ❌ Word "${word}" not tracked`);
      }
    }
    
    if (allTracked) {
      console.log('  ✅ PASS: All words tracked successfully');
    } else {
      console.log('  ❌ FAIL: Some words not tracked');
    }
    
  } catch (error) {
    console.log('  ❌ ERROR:', error.message);
  }
}

/**
 * Test 4: Case insensitivity
 */
async function testCaseInsensitivity() {
  console.log('\n📝 Test 4: Case insensitivity');
  
  const word1 = 'ტესტი';
  const word2 = 'ᲢᲔᲡᲢᲘ'; // Same word, different case
  const userId = 'test-user-4';
  
  try {
    await trackWordUsage(word1, userId);
    await trackWordUsage(word2, userId);
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    const stats1 = await getWordStats(word1);
    const stats2 = await getWordStats(word2);
    
    // Both should return the same stats (normalized)
    if (stats1 && stats2 && stats1.count === stats2.count) {
      console.log('  ✅ PASS: Case-insensitive tracking works');
      console.log('  Count:', stats1.count);
    } else {
      console.log('  ❌ FAIL: Case sensitivity issue');
      console.log('  stats1:', stats1);
      console.log('  stats2:', stats2);
    }
    
  } catch (error) {
    console.log('  ❌ ERROR:', error.message);
  }
}

/**
 * Run all tests
 */
async function runAllTests() {
  console.log('🧪 PR1 Word Validation Tests');
  console.log('================================');
  
  await testTrackWordUsage();
  await testGetNonExistentWord();
  await testTrackMultipleWords();
  await testCaseInsensitivity();
  
  console.log('\n================================');
  console.log('✅ Tests complete!');
  console.log('\nNote: These are integration tests that write to Firestore.');
  console.log('Check Firebase Console → Firestore → wordStats collection');
  console.log('to verify documents were created.');
  
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
  testTrackWordUsage,
  testGetNonExistentWord,
  testTrackMultipleWords,
  testCaseInsensitivity
};

