# Word Validation Cache Seeding

## Purpose

Pre-populate the `wordValidationCache` collection with 1000 common Georgian words to improve cold start experience for new users.

## When to Run

Run this script **once** after:
1. PR0 is deployed (message validation hook)
2. PR1-PR5 are deployed (validation functions)

## Prerequisites

1. Firebase Admin SDK initialized
2. Service account key downloaded from Firebase Console
3. PR1-PR5 validation functions deployed

## Setup

### 1. Download Service Account Key

1. Go to Firebase Console → Project Settings → Service Accounts
2. Click "Generate new private key"
3. Save as `functions/service-account-key.json`
4. **Never commit this file to git!**

Add to `.gitignore`:
```
functions/service-account-key.json
```

### 2. Install Dependencies

```bash
cd functions
npm install
```

## Usage

### Method 1: With Full Validation (Recommended)

After PR1-PR5 are deployed:

```bash
cd functions
node scripts/seedCommonWords.js
```

This will:
- Validate each word using the 5-signal system
- Cache validation results
- Take ~5-10 minutes (API calls)

### Method 2: Quick Seed (Fallback)

If you just want to seed quickly without validation:

The script currently uses placeholder validation (confidence: 0.95, source: 'seed').

To use actual validation, uncomment lines in the script:
```javascript
// const { validateGeorgianWord } = require('../wordValidation');
// const apiKey = process.env.OPENAI_API_KEY;
// const result = await validateGeorgianWord(word, 'system', apiKey);
```

## Expanding the Word List

The script includes 100 starter words. To expand to 1000:

### Option 1: Manual Curation
Add words to the `COMMON_GEORGIAN_WORDS` array in `seedCommonWords.js`

### Option 2: Import from File
Create `common_words.txt` with one word per line:
```
გამარჯობა
მადლობა
...
```

Then modify script:
```javascript
const fs = require('fs');
const words = fs.readFileSync('common_words.txt', 'utf8').split('\n');
```

### Option 3: Word Frequency List
Use Georgian word frequency data from:
- Wiktionary dumps
- Georgian language corpora
- Educational word lists

## Monitoring

Watch logs during seeding:
```bash
# In another terminal
tail -f functions/logs/seed.log
```

Expected output:
```
🌱 Starting seed: 1000 common words
  ✅ Seeded 10/1000 words...
  ✅ Seeded 20/1000 words...
  ...
✅ Seed complete!
   - Seeded: 998
   - Errors: 2
   - Total: 1000
```

## Verification

Check Firestore Console:
1. Go to Firebase Console → Firestore
2. Check `wordValidationCache` collection
3. Should see ~1000 documents
4. Each should have:
   - `word`: Georgian word
   - `valid`: true
   - `confidence`: 0.90-0.95
   - `expiresAt`: 30 days from now

## Troubleshooting

### Error: "Service account key not found"
Download the key from Firebase Console (see Setup above)

### Error: "Permission denied"
Ensure service account has Firestore write permissions

### Slow performance
Normal - each word requires API calls for validation. Takes 5-10 minutes.

### Some words fail validation
Expected - some words may be flagged as invalid by the validation system. Check logs for details.

## Next Steps

After seeding:
1. Verify cache in Firestore Console
2. Test practice generation with new user
3. Should see improved cache hit rate immediately

