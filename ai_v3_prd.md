# Product Requirements Document: AI V3 Features

## Overview
Add two AI-powered features that enhance Georgian language learning:
1. **Word Definition Lookup**: Long-press any Georgian word to see its definition and example in a modal
2. **Smart English Translation Suggestions**: Intelligently suggest Georgian translations for frequently-used English words based on user's messaging patterns

**Technical Stack**: Swift, SwiftUI, SwiftData, Firebase Cloud Functions, Firestore, OpenAI GPT-4o-mini, SSE (Server-Sent Events)

---

## Feature 1: Georgian Word Definition Lookup

### User Experience

**Trigger**: Long-press on any Georgian word in sent/received messages

**Visual Feedback**: 
- Subtle gray background appears on word during long-press
- Background disappears when modal opens
- Provides immediate visual feedback for word detection

**Modal Display**:
- Word shown in large Georgian text
- Definition in English (clear, concise explanation)
- Example sentence in Georgian with context
- Professional, minimal design

**Modal Dismiss**: Tap outside modal to close (iOS standard sheet behavior)

**Offline Handling**: Display "You're offline. Definition lookup requires internet connection." message

**Caching**: Definitions cached locally after first lookup for instant offline access on subsequent requests

**Word Detection**: Strip punctuation from word for lookup, but provide full sentence context to GPT-4 for accurate definition

---

### Technical Architecture

#### iOS Components

```
MessageBubbleView (existing)
  └── Add UILongPressGestureRecognizer
  └── Word detection at touch location
  └── Visual highlight (gray background)
  └── Call DefinitionService

DefinitionService (new)
  ├── fetchDefinition(word, conversationId, fullContext)
  ├── Check DefinitionCacheEntity (SwiftData)
  ├── If miss → check NetworkMonitor
  ├── If online → SSE request to Firebase
  └── Store in local cache

DefinitionCacheEntity (new SwiftData)
  ├── wordKey: String @Attribute(.unique)
  ├── definition: String
  ├── example: String
  ├── cachedAt: Date
  └── lastAccessedAt: Date

DefinitionModalView (new)
  ├── Display word (Georgian, 32pt bold)
  ├── Display definition (English, 16pt regular)
  ├── Display example (Georgian, 14pt italic)
  ├── Close button (X in corner)
  └── Tap outside to dismiss
```

#### Firebase Cloud Function

**Endpoint**: `getWordDefinition` (HTTPS onRequest for SSE)

**Flow**:
1. Authenticate user (Firebase Auth token)
2. Check Firestore `definitionCache` collection
3. If cache hit → return immediately via SSE
4. If cache miss → fetch RAG context (last 5 messages)
5. Call OpenAI GPT-4o-mini with prompt
6. Parse JSON response
7. Store in Firestore cache
8. Stream response via SSE

**Rate Limiting**: 30 requests per minute per user

#### OpenAI Integration

**Model**: `gpt-4o-mini` (fast, cost-effective)

**System Prompt**:
```
You are a Georgian language teacher helping English speakers learn Georgian.
Provide clear, concise definitions suitable for chat context.

Context from conversation:
{last_5_messages}

Respond ONLY with valid JSON in this exact format:
{
  "definition": "Brief English explanation of the word's meaning",
  "example": "Example Georgian sentence using the word naturally"
}
```

**User Prompt**:
```
Define the Georgian word: "{word}"
Full sentence context: "{fullSentence}"
```

**Target Latency**: <2s (95th percentile)

**Error Handling**: Retry once on timeout, fallback to cached error message

---

### Implementation Files

**New Files**:
- `swift_demo/Services/DefinitionService.swift`
- `swift_demo/Models/SwiftData/DefinitionCacheEntity.swift`
- `swift_demo/Views/Components/DefinitionModalView.swift`
- `swift_demo/Utilities/WordBoundaryDetector.swift`
- `functions/definitionFunction.js`

**Modified Files**:
- `swift_demo/Views/Chat/MessageBubbleView.swift` - Add long-press gesture, word highlight
- `swift_demo/Services/PersistenceController.swift` - Register DefinitionCacheEntity
- `functions/index.js` - Export getWordDefinition function

---

### Data Flow

```
1. User long-presses Georgian word in message
2. MessageBubbleView detects touch location
3. WordBoundaryDetector extracts word (strip punctuation)
4. Apply subtle gray background highlight
5. Haptic feedback (light impact)
6. DefinitionService.fetchDefinition(word, conversationId, fullSentence)
   a. Check DefinitionCacheEntity locally
   b. If cached → return immediately
   c. If not cached → check NetworkMonitor.isConnected
   d. If offline → return DefinitionError.offline
   e. If online → SSE request to Firebase
7. Firebase Function (getWordDefinition):
   a. Authenticate user
   b. Check Firestore definitionCache by wordKey
   c. If hit → stream cached result
   d. If miss → fetch last 5 messages (RAG)
   e. Call OpenAI GPT-4o-mini
   f. Parse JSON response
   g. Store in Firestore cache
   h. Stream result via SSE
8. Remove gray highlight
9. Display DefinitionModalView with result
10. Cache in SwiftData DefinitionCacheEntity
```

---

### Firestore Schema

**Collection**: `definitionCache`

```javascript
{
  wordKey: "გამარჯობა",           // lowercase, punctuation stripped
  definition: "A greeting meaning 'hello' or 'hi', used in casual conversation",
  example: "გამარჯობა, როგორ ხარ? (Hi, how are you?)",
  metadata: {
    hitCount: 47,
    firstCached: Timestamp,
    lastUsed: Timestamp,
    model: "gpt-4o-mini",
    avgLatencyMs: 1450
  }
}
```

**Indexing**: Create composite index on `wordKey` (ascending)

---

### Analytics Events

**Definition Lookup**:
- `definition_requested`: `{ word, cached, conversationId }`
- `definition_displayed`: `{ word, latencyMs, cached }`
- `definition_cache_hit`: `{ word, hitCount }`
- `definition_cache_miss`: `{ word }`
- `definition_offline_blocked`: `{ word }`
- `definition_error`: `{ word, errorType, errorMessage }`

---

## Feature 2: Smart English→Georgian Translation Suggestions

### User Experience

**Trigger**: User sends/receives messages with English words

**Tracking**: 
- Track English word frequency per-user (rolling 7-day window)
- Track from BOTH sent AND received messages (learn from conversations)

**Intelligence**: 
- Dynamic threshold based on user's messaging velocity
- Default: 14 uses in 7 days
- Scales with user activity (7 for low, 14 for medium, 21 for high)

**Suggestion UI**: 
- Reuse existing `GeoSuggestionBar` component
- Adapted messaging for English suggestions
- Same visual style and interactions

**Message Text**: 
- Georgian: "You're able to use {word} a lot. Now try using one of these!"
- English: "You use '{word}' often. Try using one of these Georgian translations!"

**Acceptance Behavior**: Smart replace
- If English word exists in message text → replace it with chosen Georgian word
- If English word not in text → append Georgian word (like Georgian suggestions)

**Priority**: Never show both suggestion types simultaneously
- Check Georgian suggestions first (priority)
- If none triggered → check English suggestions
- Show whichever triggered first based on message order
- Only one suggestion bar visible at any time

**Throttling**: Same as Georgian suggestions
- 1 suggestion per 3 messages
- 24-hour cooldown per word
- Session cooldown (no repeats in same session)

---

### Technical Architecture

#### iOS Components

```
EnglishUsageTrackingService (new)
  ├── Similar to WordUsageTrackingService
  ├── Track English-only words (non-Georgian script)
  ├── Track from sent AND received messages
  ├── Calculate dynamic threshold per user
  ├── isHighFrequencyEnglishWord(word) → Bool
  └── Store in EnglishUsageEntity

EnglishTranslationSuggestionService (new)
  ├── shouldShowEnglishSuggestion(text) → String?
  ├── fetchEnglishTranslations(word) → [EnglishSuggestion]
  ├── Firebase callable: suggestEnglishToGeorgian
  ├── Throttling logic (same as Georgian)
  └── 24h cooldown tracking

EnglishUsageEntity (new SwiftData)
  ├── wordKey: String @Attribute(.unique)
  ├── count7d: Int
  ├── lastUsedAt: Date
  ├── firstUsedAt: Date
  └── userVelocity: Double (cached calculation)

EnglishSuggestion (new model)
  ├── word: String (Georgian)
  ├── gloss: String (English explanation)
  ├── formality: String (informal/neutral/formal)
  └── contextHint: String (when to use)
```

#### GeoSuggestionBar Extension

**Modifications**:
- Add `suggestionType: SuggestionType` state (`.georgian` or `.english`)
- Update header text based on type
- Modify acceptance logic for smart replace
- Priority logic: check Georgian first, then English

**Smart Replace Logic**:
```swift
func acceptEnglishSuggestion(_ suggestion: EnglishSuggestion) {
    let previousText = messageText
    let triggerWord = baseEnglishWord // tracked
    
    // Smart replace
    if messageText.contains(triggerWord) {
        // Replace first occurrence
        messageText = messageText.replacingFirstOccurrence(
            of: triggerWord, 
            with: suggestion.word
        )
    } else {
        // Append with smart spacing
        if messageText.hasSuffix(" ") || messageText.isEmpty {
            messageText += suggestion.word
        } else {
            messageText += " " + suggestion.word
        }
    }
    
    // Analytics and undo setup
    logAcceptance(triggerWord, suggestion, action: contains ? "replace" : "append")
    showUndo(with: previousText)
}
```

#### Firebase Cloud Function

**Endpoint**: `suggestEnglishToGeorgian` (HTTPS onCall)

**Flow**:
1. Authenticate user
2. Rate limit check (10 requests/min/user)
3. Check Firestore `englishTranslationCache`
4. If cache hit → return immediately
5. If miss → fetch RAG context (last 10 messages)
6. Call OpenAI GPT-4o-mini
7. Parse JSON array response
8. Filter suggestions (no offensive words)
9. Store in cache (7-day TTL)
10. Return 3 suggestions

**Rate Limiting**: 10 requests per minute per user

#### OpenAI Integration

**Model**: `gpt-4o-mini`

**System Prompt**:
```
You are a Georgian language expert helping English speakers learn Georgian naturally through chat.
User frequently uses the English word "{englishWord}" in conversation.
Suggest 3 natural Georgian translations appropriate for casual messaging between friends.

Recent conversation context:
{last_10_messages}

Respond ONLY with valid JSON array:
[
  {
    "word": "georgian_word",
    "gloss": "brief English explanation",
    "formality": "informal|neutral|formal",
    "contextHint": "when to use this"
  }
]
```

**Target Latency**: <3s (95th percentile)

---

### Implementation Files

**New Files**:
- `swift_demo/Services/EnglishUsageTrackingService.swift`
- `swift_demo/Services/EnglishTranslationSuggestionService.swift`
- `swift_demo/Models/SwiftData/EnglishUsageEntity.swift`
- `swift_demo/Models/EnglishSuggestion.swift`
- `functions/englishTranslationFunction.js`

**Modified Files**:
- `swift_demo/Views/Components/GeoSuggestionBar.swift` - Support both types, smart replace
- `swift_demo/Services/MessageQueueService.swift` - Track English words on send
- `swift_demo/Services/FirestoreListenerService.swift` - Track English words on receive
- `swift_demo/Services/PersistenceController.swift` - Register EnglishUsageEntity
- `functions/index.js` - Export suggestEnglishToGeorgian

---

### Data Flow

```
1. User sends/receives message with English words
2. MessageQueueService (or FirestoreListener) → track words
3. EnglishUsageTrackingService.trackMessage(text)
   a. Tokenize text
   b. Filter English words (no Georgian script)
   c. For each word:
      - Update EnglishUsageEntity.count7d
      - Update lastUsedAt
   d. Calculate user velocity (messages per day)
   e. Persist to SwiftData
4. GeoSuggestionBar.checkForSuggestions()
   a. First: check Georgian suggestions
   b. If Georgian triggered → show Georgian, exit
   c. If no Georgian → check English suggestions
   d. EnglishTranslationSuggestionService.shouldShowEnglishSuggestion()
      - Check throttle (1 per 3 messages)
      - Find high-frequency English word
      - Check 24h cooldown
      - Check session cooldown
      - Return English word or nil
   e. If English word returned → fetch suggestions
5. Firebase Function (suggestEnglishToGeorgian):
   a. Authenticate user
   b. Rate limit check
   c. Check Firestore englishTranslationCache
   d. If hit → return cached suggestions
   e. If miss:
      - Fetch last 10 messages (RAG)
      - Call OpenAI GPT-4o-mini
      - Parse JSON array
      - Filter offensive words
      - Store in cache (7-day TTL)
      - Return suggestions
6. Display in GeoSuggestionBar with "You use '{word}' often..."
7. User accepts suggestion → smart replace or append
8. Track analytics event
```

---

### Dynamic Threshold Algorithm

```swift
func calculateDynamicThreshold(userId: String) -> Int {
    // Get message count from last 7 days
    let context = container.mainContext
    let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    
    let descriptor = FetchDescriptor<MessageEntity>(
        predicate: #Predicate { msg in
            msg.senderId == userId && msg.timestamp >= cutoffDate
        }
    )
    
    let messageCount = (try? context.fetchCount(descriptor)) ?? 0
    let avgPerDay = Double(messageCount) / 7.0
    
    // Scale threshold based on activity level
    if avgPerDay < 5 {
        return 7   // Low activity: suggest after 7 uses
    } else if avgPerDay < 20 {
        return 14  // Medium activity: suggest after 14 uses
    } else {
        return 21  // High activity: suggest after 21 uses
    }
}
```

---

### Firestore Schema

**Collection**: `englishTranslationCache`

```javascript
{
  englishWord: "hello",               // lowercase
  suggestions: [
    { 
      word: "გამარჯობა", 
      gloss: "hello (casual)", 
      formality: "informal", 
      contextHint: "friends, peers" 
    },
    { 
      word: "გაგიმარჯოს", 
      gloss: "hello (formal)", 
      formality: "formal", 
      contextHint: "elders, strangers" 
    },
    { 
      word: "სალამი", 
      gloss: "hi, greetings", 
      formality: "neutral", 
      contextHint: "any context" 
    }
  ],
  metadata: {
    hitCount: 23,
    firstCached: Timestamp,
    lastUsed: Timestamp,
    ttl: 604800000,  // 7 days in ms
    model: "gpt-4o-mini"
  }
}
```

**Indexing**: Create composite index on `englishWord` (ascending)

---

### Analytics Events

**English Suggestions**:
- `english_suggestion_exposed`: `{ englishWord, suggestionCount, userVelocity, threshold }`
- `english_suggestion_clicked`: `{ englishWord, georgianWord, formality }`
- `english_suggestion_accepted`: `{ englishWord, georgianWord, action: "replace"|"append" }`
- `english_suggestion_dismissed`: `{ englishWord, suggestionCount }`
- `english_suggestion_throttled`: `{ englishWord, reason }`

---

## Testing Requirements

### Unit Tests

**DefinitionServiceTests.swift**:
- Test cache hit/miss behavior
- Test offline error handling
- Test SSE connection and parsing
- Test word punctuation stripping
- Test LRU cache eviction

**EnglishUsageTrackingServiceTests.swift**:
- Test word tracking from sent messages
- Test word tracking from received messages
- Test English word filtering (no Georgian)
- Test dynamic threshold calculation
- Test rolling 7-day window cleanup

**EnglishTranslationSuggestionServiceTests.swift**:
- Test shouldShowEnglishSuggestion logic
- Test throttling (1 per 3 messages)
- Test 24h cooldown per word
- Test session cooldown
- Test suggestion priority (Georgian first)

### Integration Tests

**Definition E2E**:
- Long-press Georgian word → see modal
- Long-press same word again → instant (cached)
- Long-press offline → see offline message
- Long-press with punctuation → strips correctly

**English Suggestion E2E**:
- Send English word 14 times → see suggestion
- Accept suggestion (word in text) → replaces
- Accept suggestion (word not in text) → appends
- Georgian + English both high-frequency → only Georgian shows

### Performance Targets

- Definition lookup (cached): <50ms
- Definition lookup (network): <2s (95th percentile)
- English suggestion fetch (cached): <100ms
- English suggestion fetch (network): <3s (95th percentile)
- Long-press visual feedback: <100ms
- Cache hit rate: >70% after 7 days of usage
- UI responsiveness: 60 FPS maintained

---

## Security & Privacy

### Authentication
- All Firebase Functions require valid Firebase Auth token
- Token verified on every request
- Invalid/expired tokens return 401 Unauthorized

### Rate Limiting
- Definition requests: 30 per minute per user
- English suggestion requests: 10 per minute per user
- Implemented in Firebase Functions
- Rate limit state stored in Firestore `rateLimits` collection

### Data Privacy
- Word usage data is per-user (not shared between users)
- Definitions cached globally (efficiency, no privacy concern)
- English translation suggestions cached globally
- No PII stored in analytics events (word hashes only)

### Offensive Content Filtering
- Maintain filtered word lists in Firebase
- Filter suggestions server-side before returning
- Regular updates to filtered lists

---

## Deployment & Rollout

### Phase 1: Development & Testing (Week 1-2)
1. Implement iOS models and services
2. Implement Firebase Cloud Functions
3. Unit tests and integration tests
4. Internal testing with team

### Phase 2: Staging Deployment (Week 3)
1. Deploy to Firebase staging environment
2. Test with 5-10 beta users
3. Monitor performance metrics
4. Fix critical bugs

### Phase 3: Production Rollout (Week 4)
1. Deploy to production with feature flags disabled
2. Enable for 10% of users (A/B test)
3. Monitor analytics, performance, costs
4. Gradually increase to 25%, 50%, 100%
5. Full rollout if metrics look good

### Feature Flags
```swift
// iOS
UserDefaults.standard.bool(forKey: "definitionLookupEnabled")
UserDefaults.standard.bool(forKey: "englishSuggestionsEnabled")

// Firebase Functions
functions.config().features.definition_lookup === 'true'
functions.config().features.english_suggestions === 'true'
```

---

## Cost Estimation

### OpenAI API Costs

**GPT-4o-mini Pricing**:
- Input: $0.150 per 1M tokens
- Output: $0.600 per 1M tokens

**Definition Lookup** (per request):
- Input: ~200 tokens (prompt + context)
- Output: ~100 tokens (definition + example)
- Cost per request: $0.00009
- With 70% cache hit: $0.000027 effective

**English Suggestions** (per request):
- Input: ~300 tokens (prompt + context)
- Output: ~150 tokens (3 suggestions)
- Cost per request: $0.00013
- With 70% cache hit: $0.000039 effective

**Monthly Cost** (1000 active users):
- Definitions: 1000 users × 20 lookups/month × $0.000027 = $0.54
- Suggestions: 1000 users × 10 suggestions/month × $0.000039 = $0.39
- **Total: ~$1/month per 1000 users**

### Firebase Costs
- Firestore reads/writes: Negligible (cached)
- Cloud Functions invocations: Included in free tier
- Bandwidth: Minimal (SSE responses small)

---

## Success Metrics

### Engagement
- % of users who use definition lookup
- Avg definitions looked up per user per week
- % of users who accept English suggestions
- Suggestion acceptance rate

### Performance
- P50, P95, P99 latency for definitions
- P50, P95, P99 latency for suggestions
- Cache hit rates
- Error rates

### Learning Impact
- Increase in Georgian word usage after English suggestions
- Repeat definition lookups (indicates learning)
- Conversation engagement (longer messages, more Georgian)

### Target Goals (3 months post-launch)
- 40% of users use definition lookup weekly
- 25% of users accept English suggestions
- <2s P95 definition latency
- <3s P95 suggestion latency
- >70% cache hit rate
- <1% error rate

---

## Future Enhancements

### Definition Lookup
- Add pronunciation guide (IPA or audio)
- Show word conjugations/declensions
- Related words section
- Etymology information

### English Suggestions
- Suggest phrases, not just single words
- Context-aware suggestions (time of day, conversation topic)
- Gamification (streak for using Georgian)
- Progress tracking (Georgian usage %)

### General
- Offline mode with pre-loaded dictionary
- User feedback on definition/suggestion quality
- A/B test different prompts for better results
- Multi-language support (not just EN/KA)

