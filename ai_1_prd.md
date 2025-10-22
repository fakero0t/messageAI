# Product Requirements Document: AI-Powered Bilingual Translation Feature

## Overview

Add AI-powered neural translation capabilities to enable seamless bilingual communication between English and Georgian. Users view translations through double-tap interaction, with translations cached locally for performance.

**Technical Stack**: Codex, Xcode, Firebase Cloud Functions, Firestore, Anthropic Claude Sonnet 4.5, WebSocket

---

## Technical Architecture

### System Components
```
┌─────────────────────────────────────────┐
│         iOS Application Layer            │
├─────────────────────────────────────────┤
│  • Double-tap gesture recognizer         │
│  • Translation UI expansion animation    │
│  • Local translation cache (CoreData)   │
│  • WebSocket client manager              │
└─────────────────────────────────────────┘
         │                             │
         ▼                             ▼
┌──────────────────────────────────────────────────────┐
│              Firebase Cloud Functions                 │
├──────────────────────────────────────────────────────┤
│  Translation Service (WebSocket Handler)              │
│  • LLM Integration (Claude/GPT-4)                    │
│  • RAG pipeline for conversation context             │
└──────────────────────────────────────────────────────┘
         │                             │
         ▼                             ▼
┌─────────────────┐         ┌─────────────────────┐
│  Firestore DB   │         │  Realtime Database  │
│  • Messages     │         │  • WebSocket state  │
│  • Translations │         │  • Active sessions  │
│  • Cache index  │         │  • Presence data    │
└─────────────────┘         └─────────────────────┘
```

### WebSocket Flow
```
Client → TranslateRequest → Cloud Function
       ↓
Check Local Cache → Check Firestore Cache
       ↓
Detect Language (Tool Call) → Get Context (RAG)
       ↓
LLM Translation (Claude/GPT-4) → Store Cache
       ↓
WebSocket Response → Display Both Versions
```

---

## Feature Specifications

### 1. Automatic Translation Pipeline

**Message Sending:**
- Detect source language (LLM function calling)
- Translate immediately upon send
- Store both versions in Firestore
- Broadcast via WebSocket

**Storage Schema:**
```javascript
{
  messageId: "msg_123",
  senderId: "user_abc",
  conversationId: "conv_456",
  timestamp: 1698765432,
  versions: {
    en: "Hey! What's up?",
    ka: "ჰეი! რას აკეთებ?",
    original: "en"
  },
  metadata: {
    translatedAt: 1698765433,
    confidence: 0.97,
    cached: false,
    model: "claude-sonnet-4.5"
  }
}
```

### 2. Double-Tap Translation View

**UI States:**

Normal (collapsed):
```
┌─────────────────────────┐
│  Hey! What's up?        │
└─────────────────────────┘
```

Expanded:
```
┌─────────────────────────┐
│ 🇺🇸 Hey! What's up?      │
├─────────────────────────┤
│ 🇬🇪 ჰეი! რას აკეთებ?     │
└─────────────────────────┘
```

**Animation:** 300ms ease-in-out expansion

### 3. Caching Strategy

**CoreData Schema:**
```swift
@Entity TranslationCache
- messageId: String (primary key)
- textHash: String (indexed)
- englishText: String
- georgianText: String
- confidence: Float
- cachedAt: Date
- lastAccessedAt: Date
- accessCount: Int
```

**Cache Logic:**
1. Check local CoreData by textHash
2. If miss, check Firestore global cache
3. If miss, request from LLM
4. Store in both caches
5. LRU eviction at 1000 message limit

**Firestore Global Cache:**
```javascript
{
  cacheId: "hash_abc123",
  textHash: "abc123...",
  sourceText: "Hey! What's up?",
  translations: {
    en: "Hey! What's up?",
    ka: "ჰეი! რას აკეთებ?"
  },
  metadata: {
    hitCount: 47,
    firstCached: 1698765432,
    lastUsed: 1698765999
  }
}
```

---

## AI/LLM Integration

### Translation System Prompt
```
You are an expert English-Georgian translator for informal chat.

RULES:
- Preserve casual, conversational tone
- Translate meaning and intent, not literally
- Keep emojis, URLs, formatting exactly as-is
- Use natural slang/idiom equivalents
- Match formality level (casual friends)
- NEVER add explanations—only translation

EXAMPLES:
"What's up?" → "რას აკეთებ?" (NOT formal "როგორ ხართ?")
"No way!" → "არ მჯერა!"
```

### Function Calling Tools

**Language Detection:**
```json
{
  "name": "detect_language",
  "description": "Detect if text is English or Georgian",
  "parameters": {
    "text": "string",
    "context_messages": "array[string]"
  },
  "returns": {
    "language": "en|ka",
    "confidence": "float",
    "is_mixed": "boolean"
  }
}
```

### RAG Pipeline
```javascript
// Fetch last 10 messages for context
const context = await db.collection('messages')
  .where('conversationId', '==', convId)
  .where('timestamp', '<', currentMsgTimestamp)
  .orderBy('timestamp', 'desc')
  .limit(10)
  .get();

// Inject into LLM prompt
const contextStr = context.map(msg => 
  `[${msg.lang}] ${msg.text}`
).join('\n');
```

---

## Firebase Implementation

### Translation Cloud Function
```javascript
exports.translateMessage = functions
  .runWith({ timeoutSeconds: 60, memory: '1GB' })
  .https.onRequest(async (req, res) => {
    res.set({
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive'
    });

    const { messageId, text, conversationId, sourceLang } = req.body;

    try {
      // 1. Check cache
      const cached = await checkCache(text);
      if (cached) {
        sendSSE(res, { messageId, translations: cached, cached: true });
        return res.end();
      }

      // 2. Get context (RAG)
      const context = await getConversationContext(conversationId);

      // 3. Detect language
      const lang = sourceLang || await detectLanguage(text, context);

      // 4. Translate
      const translation = await translateWithClaude(text, lang, context);

      // 5. Cache and respond
      await storeInCache(text, translation);
      sendSSE(res, { messageId, translations: translation, cached: false });
      res.end();

    } catch (error) {
      sendSSE(res, { messageId, error: error.message });
      res.end();
    }
  });
```

### Auto-Translate on Message Create
```javascript
exports.onMessageCreate = functions.firestore
  .document('messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    
    if (message.versions?.en && message.versions?.ka) return;

    const originalLang = message.versions?.original || 'en';
    const originalText = message.versions?.[originalLang];

    // Check cache
    const cached = await checkCache(originalText);
    if (cached) {
      await snap.ref.update({ versions: cached.translations });
      return;
    }

    // Get context and translate
    const context = await getConversationContext(message.conversationId);
    const translation = await translateWithClaude(originalText, originalLang, context);

    await snap.ref.update({
      versions: translation,
      'metadata.translatedAt': admin.firestore.FieldValue.serverTimestamp()
    });

    await storeInCache(originalText, translation);
  });
```

### Helper Functions
```javascript
async function checkCache(text) {
  const textHash = crypto.createHash('md5').update(text.trim().toLowerCase()).digest('hex');
  const doc = await db.collection('translationCache').doc(textHash).get();
  
  if (!doc.exists) return null;
  
  // Update stats
  doc.ref.update({
    'metadata.hitCount': admin.firestore.FieldValue.increment(1),
    'metadata.lastUsed': admin.firestore.FieldValue.serverTimestamp()
  });
  
  return doc.data();
}

async function translateWithClaude(text, sourceLang, context) {
  const targetLang = sourceLang === 'en' ? 'ka' : 'en';
  const contextStr = context.slice(0, 5).map(m => `[${m.lang}] ${m.text}`).join('\n');

  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4.5-20250929',
    max_tokens: 500,
    temperature: 0.3,
    system: `Expert English-Georgian translator for casual chat. ${contextStr}`,
    messages: [{
      role: 'user',
      content: `Translate ${sourceLang} to ${targetLang}: "${text}"`
    }]
  });

  const translated = response.content[0].text.trim();

  return {
    en: sourceLang === 'en' ? text : translated,
    ka: sourceLang === 'ka' ? text : translated
  };
}
```

---

## iOS Implementation

### WebSocket Manager
```swift
class TranslationWebSocketManager: ObservableObject {
    static let shared = TranslationWebSocketManager()
    private var socket: WebSocket?
    @Published var isConnected = false
    private var callbacks: [String: (TranslationResult) -> Void] = [:]
    
    func requestTranslation(
        messageId: String,
        text: String,
        conversationId: String,
        completion: @escaping (TranslationResult) -> Void
    ) {
        // Check local cache
        if let cached = TranslationCache.shared.get(text: text) {
            completion(cached)
            return
        }
        
        callbacks[messageId] = completion
        
        let request = TranslationRequest(
            messageId: messageId,
            text: text,
            conversationId: conversationId
        )
        
        socket?.write(string: JSONEncoder().encode(request))
    }
}
```

### Message Bubble View
```swift
struct MessageBubbleView: View {
    let message: Message
    @State private var isExpanded = false
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            ZStack {
                if isLoading {
                    loadingView
                } else if isExpanded {
                    expandedBubble
                } else {
                    collapsedBubble
                }
            }
            .onTapGesture(count: 2) {
                handleDoubleTap()
            }
        }
        .animation(.spring(response: 0.3), value: isExpanded)
    }
    
    private var expandedBubble: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("🇺🇸"); Text(message.versions.en) }
            Divider()
            HStack { Text("🇬🇪"); Text(message.versions.ka) }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.blue))
    }
    
    private func handleDoubleTap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        if message.versions.en.isEmpty || message.versions.ka.isEmpty {
            fetchTranslation()
        } else {
            isExpanded.toggle()
        }
    }
    
    private func fetchTranslation() {
        isLoading = true
        TranslationWebSocketManager.shared.requestTranslation(
            messageId: message.id,
            text: message.displayText,
            conversationId: message.conversationId
        ) { result in
            message.versions = result.translations
            isLoading = false
            isExpanded = true
        }
    }
}
```

### Local Cache
```swift
class TranslationCache {
    static let shared = TranslationCache()
    private let container: NSPersistentContainer
    
    func get(text: String) -> TranslationResult? {
        let hash = text.md5
        let request: NSFetchRequest<CachedTranslation> = CachedTranslation.fetchRequest()
        request.predicate = NSPredicate(format: "textHash == %@", hash)
        
        guard let cached = try? container.viewContext.fetch(request).first else {
            return nil
        }
        
        // Update access stats
        cached.lastAccessedAt = Date()
        cached.accessCount += 1
        try? container.viewContext.save()
        
        return TranslationResult(
            messageId: cached.messageId ?? "",
            translations: .init(en: cached.englishText ?? "", ka: cached.georgianText ?? ""),
            cached: true
        )
    }
    
    func store(result: TranslationResult) {
        let context = container.viewContext
        let cached = CachedTranslation(context: context)
        cached.textHash = result.translations.en.md5
        cached.englishText = result.translations.en
        cached.georgianText = result.translations.ka
        cached.cachedAt = Date()
        try? context.save()
        evictOldEntries()
    }
    
    private func evictOldEntries() {
        let request: NSFetchRequest<CachedTranslation> = CachedTranslation.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "lastAccessedAt", ascending: true)]
        
        guard let all = try? container.viewContext.fetch(request), all.count > 1000 else { return }
        
        all.prefix(all.count - 1000).forEach { container.viewContext.delete($0) }
        try? container.viewContext.save()
    }
}
```

---

## Testing

### Unit Tests
```swift
func testCacheStoreAndRetrieve() {
    let result = TranslationResult(
        messageId: "test_123",
        translations: .init(en: "Hello", ka: "გამარჯობა"),
        cached: false
    )
    TranslationCache.shared.store(result: result)
    let retrieved = TranslationCache.shared.get(text: "Hello")
    
    XCTAssertNotNil(retrieved)
    XCTAssertEqual(retrieved?.translations.ka, "გამარჯობა")
}

func testTranslationLatency() {
    let expectation = XCTestExpectation(description: "Translation")
    var latency: TimeInterval = 0
    
    TranslationManager.shared.translate(
        messageId: "test",
        text: "Hello!",
        conversationId: "conv"
    ) { result in
        latency = result.latency ?? 0
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 10)
    XCTAssertLessThan(latency, 5.0)
}
```

### Quality Tests
```swift
func testCasualTonePreserved() {
    // "What's up?" should be "რას აკეთებ?" not formal "როგორ ხართ?"
    let result = translate("What's up?", from: "en")
    XCTAssertEqual(result.ka, "რას აკეთებ?")
}

func testEmojiPreservation() {
    let result = translate("😂 That's funny!", from: "en")
    XCTAssertTrue(result.ka.contains("😂"))
}

func testURLPreservation() {
    let url = "https://example.com"
    let result = translate("Check \(url)", from: "en")
    XCTAssertTrue(result.ka.contains(url))
}
```

---

## Analytics
```swift
class TranslationAnalytics {
    func logTranslationCompleted(
        messageId: String,
        latency: TimeInterval,
        cached: Bool
    ) {
        Analytics.logEvent("translation_completed", parameters: [
            "message_id": messageId,
            "latency_ms": Int(latency * 1000),
            "cached": cached
        ])
    }
    
    func logQualityRating(messageId: String, rating: Int) {
        Analytics.logEvent("translation_quality_rating", parameters: [
            "message_id": messageId,
            "rating": rating
        ])
    }
}
```

---

## Setup Instructions

### Firebase
```bash
firebase init
firebase functions:config:set anthropic.key="sk-ant-..."
firebase deploy --only functions
```

### iOS
```ruby
# Podfile
pod 'Firebase/Firestore'
pod 'Firebase/Functions'
pod 'Starscream'
```
```swift
// AppDelegate
FirebaseApp.configure()
```

### Environment Variables
```javascript
// functions/.env
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-... // fallback
CACHE_TTL_DAYS=30
MAX_CONTEXT_MESSAGES=10
```