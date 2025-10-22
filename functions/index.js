const functions = require('firebase-functions');
const admin = require('firebase-admin');

try { admin.initializeApp(); } catch (_) {}
const db = admin.firestore();

// Feature flag removed: always enabled

// Util: write SSE event
function sseWrite(res, data) {
  res.write(`data: ${JSON.stringify(data)}\n\n`);
}

// Cache helpers
function textHash(text) {
  const crypto = require('crypto');
  return crypto.createHash('md5').update(text.trim().toLowerCase()).digest('hex');
}

async function checkCache(text) {
  const hash = textHash(text);
  const doc = await db.collection('translationCache').doc(hash).get();
  if (!doc.exists) return null;
  await doc.ref.update({
    'metadata.hitCount': admin.firestore.FieldValue.increment(1),
    'metadata.lastUsed': admin.firestore.FieldValue.serverTimestamp()
  });
  return doc.data();
}

async function storeInCache(text, translations) {
  const hash = textHash(text);
  const ref = db.collection('translationCache').doc(hash);
  await ref.set({
    textHash: hash,
    sourceText: text,
    translations,
    metadata: {
      hitCount: 0,
      firstCached: admin.firestore.FieldValue.serverTimestamp(),
      lastUsed: admin.firestore.FieldValue.serverTimestamp()
    }
  }, { merge: true });
}

// Context fetch
async function getConversationContext(conversationId, beforeTs, limit = Number(process.env.MAX_CONTEXT_MESSAGES || 10)) {
  const q = await db.collection('messages')
    .where('conversationId', '==', conversationId)
    .where('timestamp', '<', beforeTs)
    .orderBy('timestamp', 'desc')
    .limit(limit)
    .get();
  return q.docs.map(d => d.data());
}

// OpenAI translate
async function translateWithOpenAI({ text, sourceLang, context }) {
  // Placeholder in PR02: echo translation (real GPT-4o coming in PR06)
  // Preserve interface now; real call will stream deltas
  const targetLang = sourceLang === 'en' ? 'ka' : 'en';
  return {
    en: sourceLang === 'en' ? text : `[EN] ${text}`,
    ka: sourceLang === 'ka' ? text : `[KA] ${text}`,
    original: sourceLang
  };
}

exports.translateMessage = functions
  .runWith({ timeoutSeconds: 60, memory: '1GB' })
  .https.onRequest(async (req, res) => {
    res.set({
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive'
    });

    // Always enabled

    // Auth
    try {
      const authHeader = req.headers.authorization || '';
      const token = authHeader.startsWith('Bearer ') ? authHeader.substring(7) : null;
      if (!token) throw new Error('missing token');
      await admin.auth().verifyIdToken(token);
    } catch (e) {
      sseWrite(res, { type: 'error', error: 'unauthorized' });
      return res.end();
    }

    const { messageId, text, conversationId, sourceLang = 'en', timestamp } = req.body || {};
    if (!messageId || !text || !conversationId || !timestamp) {
      sseWrite(res, { type: 'error', error: 'invalid_request' });
      return res.end();
    }

    try {
      // 1) cache
      const cached = await checkCache(text);
      if (cached?.translations) {
        sseWrite(res, { type: 'final', messageId, translations: cached.translations, cached: true });
        return res.end();
      }

      // 2) context
      const context = await getConversationContext(conversationId, timestamp, Number(process.env.MAX_CONTEXT_MESSAGES || 10));

      // 3) translate
      const translations = await translateWithOpenAI({ text, sourceLang, context });

      // 4) store cache & respond
      await storeInCache(text, translations);
      sseWrite(res, { type: 'final', messageId, translations, cached: false });
      return res.end();
    } catch (e) {
      sseWrite(res, { type: 'error', messageId, error: e.message || 'unknown_error' });
      return res.end();
    }
  });

// --- PR03: Firestore onCreate trigger ---
function detectLanguageSimple(text) {
  // Simple heuristic: if it contains Georgian script chars, assume 'ka'
  // Unicode Georgian: \u10A0-\u10FF
  const georgianRegex = /[\u10A0-\u10FF]/;
  return georgianRegex.test(text) ? 'ka' : 'en';
}

exports.onMessageCreate = functions.firestore
  .document('messages/{messageId}')
  .onCreate(async (snap, context) => {
    try {
      // Always enabled
      const message = snap.data();
      if (!message) return;

      // If both versions present, skip
      if (message.versions && message.versions.en && message.versions.ka) return;

      const originalText = message.versions?.text || message.text || '';
      if (!originalText) return;

      // Cache check
      const cached = await checkCache(originalText);
      if (cached?.translations) {
        await snap.ref.update({
          versions: cached.translations,
          'metadata.translatedAt': admin.firestore.FieldValue.serverTimestamp()
        });
        return;
      }

      // Context and lang
      const originalLang = message.versions?.original || detectLanguageSimple(originalText);
      const contextMsgs = await getConversationContext(message.conversationId, message.timestamp || Date.now());

      // Translate
      const translations = await translateWithOpenAI({ text: originalText, sourceLang: originalLang, context: contextMsgs });

      // Update doc and cache
      await snap.ref.update({
        versions: translations,
        'metadata.translatedAt': admin.firestore.FieldValue.serverTimestamp()
      });
      await storeInCache(originalText, translations);
    } catch (e) {
      console.error('onMessageCreate error', e);
    }
  });


