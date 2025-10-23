// Clear all cached practice batches
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

async function clearPracticeCache() {
  console.log('🗑️  Clearing practice cache...');
  
  const snapshot = await db.collection('practiceCache').get();
  
  if (snapshot.empty) {
    console.log('✅ No cached practice batches found');
    process.exit(0);
  }
  
  console.log(`Found ${snapshot.size} cached batch(es)`);
  
  const batch = db.batch();
  snapshot.docs.forEach(doc => {
    batch.delete(doc.ref);
  });
  
  await batch.commit();
  console.log('✅ Cleared all practice cache entries');
  process.exit(0);
}

clearPracticeCache().catch(error => {
  console.error('❌ Error:', error);
  process.exit(1);
});

