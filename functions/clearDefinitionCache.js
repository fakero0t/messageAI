#!/usr/bin/env node

/**
 * Script to clear definition cache from Firestore
 * Usage: node clearDefinitionCache.js [--all|--word=WORD]
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function clearAllDefinitions() {
  console.log('🗑️  Clearing ALL definitions from cache...');
  
  const snapshot = await db.collection('definitionCache').get();
  const batch = db.batch();
  
  snapshot.docs.forEach(doc => {
    batch.delete(doc.ref);
  });
  
  await batch.commit();
  console.log(`✅ Deleted ${snapshot.size} cached definitions`);
}

async function clearSpecificWord(word) {
  console.log(`🗑️  Clearing definition for word: ${word}`);
  
  // Hash the word (same as in definitionFunction.js)
  const crypto = require('crypto');
  const hash = crypto.createHash('md5').update(word.trim().toLowerCase()).digest('hex');
  
  const docRef = db.collection('definitionCache').doc(hash);
  const doc = await docRef.get();
  
  if (!doc.exists) {
    console.log(`⚠️  No cached definition found for: ${word}`);
    return;
  }
  
  await docRef.delete();
  console.log(`✅ Deleted cached definition for: ${word}`);
}

async function listCachedDefinitions() {
  console.log('📋 Listing all cached definitions...\n');
  
  const snapshot = await db.collection('definitionCache')
    .orderBy('metadata.lastUsed', 'desc')
    .limit(50)
    .get();
  
  if (snapshot.empty) {
    console.log('No cached definitions found.');
    return;
  }
  
  console.log(`Found ${snapshot.size} cached definitions:\n`);
  
  snapshot.docs.forEach((doc, index) => {
    const data = doc.data();
    const lastUsed = data.metadata?.lastUsed?.toDate?.() || 'Unknown';
    console.log(`${index + 1}. ${data.wordKey}`);
    console.log(`   Definition: ${data.definition?.substring(0, 60)}...`);
    console.log(`   Hit count: ${data.metadata?.hitCount || 0}`);
    console.log(`   Last used: ${lastUsed}`);
    console.log('');
  });
}

async function getStats() {
  console.log('📊 Cache Statistics:\n');
  
  const snapshot = await db.collection('definitionCache').get();
  
  if (snapshot.empty) {
    console.log('No cached definitions.');
    return;
  }
  
  let totalHits = 0;
  const docs = snapshot.docs;
  
  docs.forEach(doc => {
    const data = doc.data();
    totalHits += data.metadata?.hitCount || 0;
  });
  
  console.log(`Total cached words: ${docs.length}`);
  console.log(`Total cache hits: ${totalHits}`);
  console.log(`Average hits per word: ${(totalHits / docs.length).toFixed(2)}`);
  console.log(`Cache efficiency: ${((totalHits / (totalHits + docs.length)) * 100).toFixed(1)}%`);
}

// Main execution
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0 || args.includes('--help')) {
    console.log(`
Definition Cache Management Tool

Usage:
  node clearDefinitionCache.js --all              Clear all cached definitions
  node clearDefinitionCache.js --word=WORD        Clear specific word
  node clearDefinitionCache.js --list             List all cached definitions
  node clearDefinitionCache.js --stats            Show cache statistics
  node clearDefinitionCache.js --help             Show this help

Examples:
  node clearDefinitionCache.js --all
  node clearDefinitionCache.js --word=გამარჯობა
  node clearDefinitionCache.js --list
  node clearDefinitionCache.js --stats
    `);
    process.exit(0);
  }
  
  try {
    if (args.includes('--all')) {
      await clearAllDefinitions();
    } else if (args.includes('--list')) {
      await listCachedDefinitions();
    } else if (args.includes('--stats')) {
      await getStats();
    } else {
      const wordArg = args.find(arg => arg.startsWith('--word='));
      if (wordArg) {
        const word = wordArg.split('=')[1];
        await clearSpecificWord(word);
      } else {
        console.error('❌ Invalid argument. Use --help for usage information.');
        process.exit(1);
      }
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

main();

