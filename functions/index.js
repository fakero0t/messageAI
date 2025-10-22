const functions = require('firebase-functions');
const admin = require('firebase-admin');
const fetch = require('node-fetch');

try { admin.initializeApp(); } catch (_) {}
const db = admin.firestore();

// OpenAI key helper
function getOpenAIKey() {
  try {
    const cfg = functions.config();
    if (cfg && cfg.openai && cfg.openai.key) return cfg.openai.key;
  } catch (_) {}
  return process.env.OPENAI_API_KEY;
}

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

// Build context string for RAG-lite
function buildContextString(context = []) {
  return context.slice(0, Number(process.env.MAX_CONTEXT_MESSAGES || 10))
    .map(m => {
      const lang = detectLanguageSimple(String(m.text || ''));
      return `[${lang}] ${String(m.text || '')}`;
    })
    .join('\n');
}

// OpenAI translate (GPT-4o family)
async function translateWithOpenAI({ text, sourceLang, context }) {
  const apiKey = getOpenAIKey();
  const contextStr = buildContextString(context);
  if (!apiKey) {
    console.warn('OPENAI_API_KEY missing; returning placeholder translation');
    return {
      en: sourceLang === 'en' ? text : `[EN] ${text}`,
      ka: sourceLang === 'ka' ? text : `[KA] ${text}`,
      original: sourceLang
    };
  }

  // Reliable approach: compute both lines explicitly with targeted calls.
  const enLine = sourceLang === 'en'
    ? text
    : await singleTargetTranslate({ apiKey, text, target: 'en', contextStr, sourceLang });
  const kaLine = sourceLang === 'ka'
    ? text
    : await singleTargetTranslate({ apiKey, text, target: 'ka', contextStr, sourceLang });
  return { en: enLine, ka: kaLine, original: sourceLang };

// --- PR06: NL commands endpoint ---
exports.nlCommand = functions
  .runWith({ timeoutSeconds: 60, memory: '1GB' })
  .https.onRequest(async (req, res) => {
    res.set({ 'Content-Type': 'application/json' });
    try {
      // Auth (reuse pattern from translateMessage)
      const authHeader = req.headers.authorization || '';
      const token = authHeader.startsWith('Bearer ') ? authHeader.substring(7) : null;
      if (!token) return res.status(401).json({ error: 'unauthorized' });
      await admin.auth().verifyIdToken(token);

      const { intent, text, conversationId, timestamp } = req.body || {};
      if (!intent || !text) return res.status(400).json({ error: 'invalid_request' });
      const context = conversationId && timestamp ? await getConversationContext(conversationId, timestamp) : [];
      const contextStr = buildContextString(context);
  const apiKey = getOpenAIKey();
      if (!apiKey) return res.status(200).json({ result: defaultNlFallback(intent, text) });

      const prompts = buildNlPrompts(intent, text, contextStr);
      const start = Date.now();
      const body = {
        model: 'gpt-4o-mini', temperature: 0.2, max_tokens: 600,
        messages: [ { role: 'system', content: prompts.system }, { role: 'user', content: prompts.user } ]
      };
      const controllerNL = new AbortController();
      const timeoutNL = setTimeout(() => controllerNL.abort(), 15000);
      const r = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST', headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body)
      , signal: controllerNL.signal });
      clearTimeout(timeoutNL);
      if (!r.ok) {
        const t = await r.text().catch(() => '');
        return res.status(500).json({ error: `openai_error_${r.status}`, details: t });
      }
      const data = await r.json();
      const content = data.choices?.[0]?.message?.content?.trim?.() || '';
      const latencyMs = Date.now() - start;
      console.log(JSON.stringify({ event: 'nl_command', intent, latencyMs }));
      return res.status(200).json({ result: content });
    } catch (e) {
      return res.status(500).json({ error: 'server_error', details: String(e) });
    }
  });

function buildNlPrompts(intent, text, contextStr) {
  const baseSystem = [
    'You assist a bilingual chat app (English–Georgian).',
    'Be concise and clear. Preserve emojis and URLs. Use casual tone when appropriate.',
    'Context (most recent first):', contextStr
  ].join('\n');
  switch (intent) {
    case 'explain_slang':
      return {
        system: baseSystem,
        user: `Explain the slang/idioms in: ${text}. Provide a short, friendly explanation.`
      };
    case 'adjust_tone_formal':
      return {
        system: baseSystem,
        user: `Rewrite more formally while preserving meaning and cultural nuance: ${text}`
      };
    case 'adjust_tone_casual':
      return {
        system: baseSystem,
        user: `Rewrite more casually with natural idioms while preserving meaning: ${text}`
      };
    case 'cultural_hint':
      return {
        system: baseSystem,
        user: `Provide a helpful cultural context hint for understanding this message: ${text}`
      };
    default:
      return { system: baseSystem, user: `Explain briefly: ${text}` };
  }
}

function defaultNlFallback(intent, text) {
  switch (intent) {
    case 'explain_slang': return 'Slang explanation unavailable (no API key).';
    case 'adjust_tone_formal': return text;
    case 'adjust_tone_casual': return text;
    case 'cultural_hint': return 'Cultural hint unavailable (no API key).';
    default: return text;
  }
}
  if (!resp.ok) {
    const errText = await resp.text().catch(() => '');
    throw new Error(`OpenAI error ${resp.status}: ${errText}`);
  }

  const data = await resp.json();
  const content = data.choices?.[0]?.message?.content || '';
  let parsed;
  try { parsed = JSON.parse(content); } catch (_) { parsed = null; }

  if (!parsed || typeof parsed.en !== 'string' || typeof parsed.ka !== 'string') {
    // Fallback heuristic: ask twice (once per target) if JSON parse fails
    const en = sourceLang === 'en' ? text : await singleTargetTranslate({ apiKey, text, target: 'en', contextStr });
    const ka = sourceLang === 'ka' ? text : await singleTargetTranslate({ apiKey, text, target: 'ka', contextStr });
    return { en, ka, original: sourceLang };
  }

  return { en: parsed.en, ka: parsed.ka, original: sourceLang };
}

async function singleTargetTranslate({ apiKey, text, target, contextStr, sourceLang }) {
  const sys = [
    'You are an expert English–Georgian translator for informal chat.',
    'Preserve emojis, URLs, and formatting exactly as-is.',
    `Source language is likely: ${sourceLang}. Target language is: ${target}.`,
    'Translate all parts not already in the target language; keep any target-language segments unchanged.',
    'If the entire input is already in the target language, return it unchanged.',
    '',
    'Context (most recent first):',
    contextStr
  ].join('\n');
  const usr = `Translate to target <${target}> with rules above. Input:\n${text}\nRespond with only the final text in the target language.`;
  const body = {
    model: 'gpt-4o-mini',
    temperature: 0.2,
    max_tokens: 400,
    messages: [
      { role: 'system', content: sys },
      { role: 'user', content: usr }
    ]
  };
  const controllerST = new AbortController();
  const timeoutST = setTimeout(() => controllerST.abort(), 15000);
  const resp = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST', headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body)
  , signal: controllerST.signal });
  clearTimeout(timeoutST);
  const data = await resp.json();
  return data.choices?.[0]?.message?.content?.trim?.() || text;
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

    const { messageId, text, conversationId, timestamp } = req.body || {};
    if (!messageId || !text || !conversationId || !timestamp) {
      sseWrite(res, { type: 'error', error: 'invalid_request' });
      return res.end();
    }

    try {
      // 1) cache
      const cached = await checkCache(text);
      if (cached?.translations) {
        console.log(JSON.stringify({ event: 'cache_hit', messageId }));
        sseWrite(res, { type: 'final', messageId, translations: cached.translations, cached: true });
        return res.end();
      }

      // 2) context
      const context = await getConversationContext(conversationId, timestamp, Number(process.env.MAX_CONTEXT_MESSAGES || 10));
      const sourceLang = detectLanguageSimple(text);

      // 3) translate
      const start = Date.now();
      const translations = await translateWithOpenAI({ text, sourceLang, context });
      const latencyMs = Date.now() - start;

      // 4) store cache & respond
      await storeInCache(text, translations);
      console.log(JSON.stringify({ event: 'translate_done', messageId, latencyMs }));
      sseWrite(res, { type: 'final', messageId, translations, cached: false });
      return res.end();
    } catch (e) {
      console.error(JSON.stringify({ event: 'translate_error', messageId, error: String(e) }));
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


