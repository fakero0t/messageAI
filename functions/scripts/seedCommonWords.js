/**
 * Seed script: Pre-populate wordValidationCache with 1000 common Georgian words
 * Run this once after PR0 is deployed and PR1-PR5 are complete
 * 
 * Usage: node scripts/seedCommonWords.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json'); // You'll need to download this

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// TODO: Expand this to 1000 common Georgian words
// This is a starter list of 100 words - expand with:
// - Georgian word frequency lists
// - Common conversation words
// - Educational vocabulary

const COMMON_GEORGIAN_WORDS = [
  // Greetings & Basic (20)
  'გამარჯობა', 'გაუმარჯოს', 'ნახვამდის', 'მადლობა', 'გმადლობთ',
  'კი', 'არა', 'დიახ', 'კარგი', 'ცუდი',
  'გეთაყვა', 'გეთაყვათ', 'ბოდიში', 'უკაცრავად', 'სიამოვნებით',
  'არაფრის', 'რა', 'როგორ', 'სად', 'როდის',
  
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
  
  // Pronouns & Question Words (20)
  'მე', 'შენ', 'ის', 'ჩვენ', 'თქვენ', 'ისინი',
  'ვინ', 'რატომ', 'რამდენი', 'რომელი', 'ვისი',
  'რომ', 'რომც', 'როცა', 'სადაც', 'რომლის',
  'ვისაც', 'რასაც', 'როგორც', 'რამდენც'
];

/**
 * Cache a validation result
 * NOTE: This mimics the cacheValidationResult function from index.js
 * In production, this would call the actual validation function
 */
async function seedWord(word) {
  const normalized = word.toLowerCase().trim();
  const now = Date.now();
  const expiresAt = admin.firestore.Timestamp.fromMillis(now + 30 * 24 * 60 * 60 * 1000); // 30 days
  
  // For seeding, we assume these words are valid with high confidence
  // In production with PR1-PR5, this would call validateGeorgianWord()
  await db.collection('wordValidationCache').doc(normalized).set({
    word: word,
    valid: true,
    confidence: 0.95, // High confidence for curated common words
    source: 'seed',
    signals: [{
      source: 'seed',
      confidence: 0.95,
      valid: true
    }],
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: expiresAt,
    userId: 'system'
  }, { merge: true });
}

/**
 * Main seeding function
 */
async function seedCache() {
  console.log(`🌱 Starting seed: ${COMMON_GEORGIAN_WORDS.length} common words`);
  
  let seeded = 0;
  let errors = 0;
  
  for (const word of COMMON_GEORGIAN_WORDS) {
    try {
      await seedWord(word);
      seeded++;
      
      if (seeded % 10 === 0) {
        console.log(`  ✅ Seeded ${seeded}/${COMMON_GEORGIAN_WORDS.length} words...`);
      }
    } catch (error) {
      errors++;
      console.error(`  ❌ Failed to seed "${word}": ${error.message}`);
    }
  }
  
  console.log(`\n✅ Seed complete!`);
  console.log(`   - Seeded: ${seeded}`);
  console.log(`   - Errors: ${errors}`);
  console.log(`   - Total: ${COMMON_GEORGIAN_WORDS.length}`);
  
  process.exit(0);
}

// Run seeding
seedCache().catch(error => {
  console.error('❌ Seed failed:', error);
  process.exit(1);
});

