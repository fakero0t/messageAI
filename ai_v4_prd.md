# Product Requirements Document: AI V4 - Context-Aware Smart Practice

## Overview
Add an AI-powered Georgian spelling practice feature that analyzes user's conversation history to identify letter confusion patterns and generates personalized multiple-choice exercises.

**Technical Stack**: Swift, SwiftUI, Firebase Cloud Functions, Firestore, OpenAI GPT-4, RAG pipeline

---

## Feature: Context-Aware Smart Practice

### User Experience

**Navigation**: Third tab in main TabView (Chats | Profile | Practice)

**Practice Flow**:
1. User taps "Practice" tab
2. Loading state shows while generating practice batch
3. First question displays with:
   - Word with one letter missing (underscore shown)
   - Three letter choices (A, B, C format)
   - Progress indicator "Question 1 of 15" at top
4. User selects a letter
5. Result shows:
   - ✓ Correct or ✗ Incorrect feedback
   - Complete word revealed
   - Brief explanation (e.g., "This letter is commonly used in this position")
   - "Next Question" button
6. User taps "Next Question" → next question appears
7. After completing all questions:
   - Summary screen shows completion
   - "Generate New Practice" button
   - "Restart This Batch" button

**Personalization Logic**:
- **Enough Data** (≥20 messages sent): Personalized practice based on user's letter confusion patterns
- **Limited Data** (<20 messages): Generic Georgian spelling practice with common words

**Visual Design**:
- Clean, game-like interface
- Large, readable Georgian text
- Color-coded feedback (green for correct, red for incorrect)
- Progress bar at top
- Minimal distractions

**Offline Handling**: Display "You're offline. Practice requires internet connection." message

**Empty State** (no practice available): "Complete more conversations to unlock personalized practice!"

---

### Technical Architecture

#### iOS Components

```
PracticeView (new)
  ├── Navigation tab item (third tab)
  ├── Loading state (skeleton UI)
  ├── PracticeQuestionCard (current question)
  ├── Progress indicator
  └── Completion screen with actions

PracticeViewModel (new)
  ├── @Published currentBatch: [PracticeItem]
  ├── @Published currentIndex: Int
  ├── @Published showResult: Bool
  ├── @Published isLoading: Bool
  ├── generateNewBatch()
  ├── submitAnswer(letter)
  ├── nextQuestion()
  └── restartBatch()

PracticeService (new)
  ├── fetchPracticeBatch(userId) → [PracticeItem]
  ├── Check user message count
  ├── If <20 messages → request generic
  ├── If ≥20 messages → request personalized
  ├── Firebase callable: generatePractice
  └── Cache batch locally (in-memory)

PracticeItem (new model)
  ├── id: String
  ├── word: String (complete word)
  ├── displayWord: String (with underscore)
  ├── missingIndex: Int (position of missing letter)
  ├── correctLetter: String
  ├── options: [String] (3 letters including correct)
  ├── explanation: String
  └── source: PracticeSource (.personalized | .generic)

PracticeQuestionCard (new)
  ├── Display word with missing letter
  ├── Three choice buttons (A, B, C)
  ├── Handle selection
  └── Haptic feedback on tap

PracticeResultCard (new)
  ├── Show ✓/✗ result
  ├── Display complete word
  ├── Show explanation
  └── "Next Question" button
```

#### Firebase Cloud Function

**Endpoint**: `generatePractice` (HTTPS onCall)

**Flow**:
1. Authenticate user (Firebase Auth token)
2. Rate limit check (5 requests per minute per user)
3. Check Firestore `practiceCache` for cached batch (1-hour TTL)
4. If cache hit → return immediately
5. If cache miss:
   a. Fetch user's message count
   b. If <20 messages → call GPT-4 with generic prompt
   c. If ≥20 messages:
      - Fetch last 50 messages per conversation (RAG)
      - Filter to only user's sent messages
      - Call GPT-4 with personalized prompt
6. Parse JSON response (array of 10-20 practice items)
7. Validate and filter responses
8. Store in Firestore cache (1-hour TTL)
9. Return practice batch

**Rate Limiting**: 5 requests per minute per user

---

#### OpenAI Integration

**Model**: `gpt-4` (NOT gpt-4o-mini - need better analysis quality)

**System Prompt (Personalized)**:
```
You are a Georgian language teacher creating personalized spelling practice for an English speaker learning Georgian.

CONTEXT:
The user has sent the following messages in their conversations (grouped by conversation):
{conversation_summaries}

TASK:
Analyze the user's Georgian text for letter confusion patterns:
1. Letters they frequently misplace (wrong position in words)
2. Letters they avoid using
3. Letters they overuse incorrectly
4. Common misspellings

Generate 15 practice items focusing on these problematic letters. Each item should:
- Use words the user has actually typed OR relevant words from conversation topics
- Remove ONE letter that the user struggles with
- Provide 3 letter choices:
  * The correct letter
  * A commonly confused Georgian letter
  * A visually similar Georgian letter

Respond ONLY with valid JSON array:
[
  {
    "word": "complete_georgian_word",
    "missingIndex": 3,
    "correctLetter": "ი",
    "options": ["ი", "უ", "ო"],
    "explanation": "This letter is commonly used in this position for verbs"
  }
]

RULES:
- Use only Georgian script (Unicode U+10A0 to U+10FF)
- Ensure options are randomized (correct letter not always first)
- Focus on letters user struggles with
- Keep explanations brief and helpful (under 80 characters)
- Return exactly 15 items
```

**System Prompt (Generic)**:
```
You are a Georgian language teacher creating spelling practice for an English speaker learning Georgian.

TASK:
Generate 15 practice items using common Georgian words suitable for beginners.

Each item should:
- Use a common, useful Georgian word
- Remove ONE letter
- Provide 3 letter choices:
  * The correct letter
  * A commonly confused Georgian letter
  * A visually similar Georgian letter

Respond ONLY with valid JSON array:
[
  {
    "word": "გამარჯობა",
    "missingIndex": 3,
    "correctLetter": "ა",
    "options": ["ა", "ო", "ე"],
    "explanation": "Common greeting word - 'hello'"
  }
]

RULES:
- Use only Georgian script (Unicode U+10A0 to U+10FF)
- Ensure options are randomized (correct letter not always first)
- Focus on commonly confused letters (ი/უ, ა/ო, ე/ი, etc.)
- Keep explanations brief and helpful (under 80 characters)
- Return exactly 15 items
```

**User Prompt (Personalized)**:
```
Analyze the conversation history and generate personalized spelling practice focusing on letters the user struggles with.
```

**User Prompt (Generic)**:
```
Generate generic spelling practice for a beginner learning Georgian.
```

**Target Latency**: <8s (95th percentile)

**Error Handling**: 
- Retry once on timeout
- Fallback to generic practice if personalized fails
- Cache valid responses aggressively

---

### Implementation Files

**New Files**:
- `swift_demo/Services/PracticeService.swift`
- `swift_demo/ViewModels/PracticeViewModel.swift`
- `swift_demo/Views/Practice/PracticeView.swift`
- `swift_demo/Views/Practice/PracticeQuestionCard.swift`
- `swift_demo/Views/Practice/PracticeResultCard.swift`
- `swift_demo/Views/Practice/PracticeCompletionView.swift`
- `swift_demo/Models/PracticeItem.swift`
- `functions/practiceFunction.js`

**Modified Files**:
- `swift_demo/Views/MainView.swift` - Add third tab for Practice
- `functions/index.js` - Export generatePractice function

---

### Data Flow

```
1. User taps "Practice" tab
2. PracticeView appears → shows loading skeleton
3. PracticeViewModel.generateNewBatch()
4. PracticeService.fetchPracticeBatch(userId)
   a. Check in-memory cache (if recently fetched)
   b. If cached → return immediately
   c. If not cached → check NetworkMonitor.isConnected
   d. If offline → return PracticeError.offline
   e. If online → call Firebase function
5. Firebase Function (generatePractice):
   a. Authenticate user
   b. Rate limit check (5 req/min)
   c. Check Firestore practiceCache by userId
   d. If hit → return cached batch
   e. If miss:
      - Count user's sent messages
      - If <20 → call GPT-4 with generic prompt
      - If ≥20:
        * Fetch last 50 messages per conversation
        * Filter to user's sent messages only
        * Build conversation summaries for RAG
        * Call GPT-4 with personalized prompt
   f. Parse JSON array response
   g. Validate structure and Georgian script
   h. Store in Firestore cache (1-hour TTL)
   i. Return practice batch
6. PracticeViewModel receives batch
7. Set currentIndex = 0, display first question
8. User selects letter
9. Show PracticeResultCard with feedback
10. User taps "Next Question"
11. Increment currentIndex, show next question
12. Repeat until currentIndex == batch.count
13. Show PracticeCompletionView
14. User taps "Generate New Practice" → go to step 3
    OR "Restart This Batch" → go to step 7
```

---

### Firestore Schema

**Collection**: `practiceCache`

```javascript
{
  userId: "user_abc123",
  batch: [
    {
      word: "გამარჯობა",
      missingIndex: 3,
      correctLetter: "ა",
      options: ["ა", "ო", "ე"],
      explanation: "Common greeting - 'hello'"
    }
  ],
  source: "personalized",  // or "generic"
  metadata: {
    generatedAt: Timestamp,
    ttl: 3600000,  // 1 hour in ms
    messageCount: 47,
    model: "gpt-4",
    latencyMs: 6200
  }
}
```

**Indexing**: Create composite index on `userId` (ascending)

**TTL**: 1 hour (refresh practice regularly to reflect new patterns)

---

### Analytics Events

**Practice Engagement**:
- `practice_tab_opened`: `{ userId, timestamp }`
- `practice_batch_requested`: `{ userId, source, messageCount }`
- `practice_batch_generated`: `{ userId, source, itemCount, latencyMs, cached }`
- `practice_batch_cache_hit`: `{ userId }`
- `practice_batch_cache_miss`: `{ userId, reason }`
- `practice_batch_error`: `{ userId, errorType, errorMessage }`

**Practice Completion**:
- `practice_question_answered`: `{ userId, questionIndex, correct, letter, source }`
- `practice_batch_completed`: `{ userId, correctCount, totalCount, source }`
- `practice_batch_restarted`: `{ userId }`
- `practice_new_batch_requested`: `{ userId }`

**Offline Events**:
- `practice_offline_blocked`: `{ userId }`

---

## Testing Requirements

### Unit Tests

**PracticeServiceTests.swift**:
- Test personalized vs generic logic (message count threshold)
- Test offline error handling
- Test Firebase callable integration
- Test in-memory caching
- Test JSON parsing and validation

**PracticeViewModelTests.swift**:
- Test batch state management
- Test currentIndex progression
- Test answer submission (correct/incorrect)
- Test restart batch functionality
- Test generate new batch functionality

### Integration Tests

**Practice E2E**:
- New user (<20 messages) → see generic practice
- Active user (≥20 messages) → see personalized practice
- Complete all 15 questions → see completion screen
- Tap "Generate New Practice" → new batch loads
- Tap "Restart This Batch" → same batch, index resets
- Go offline → see offline message

### Performance Targets

- Practice batch generation (cached): <200ms
- Practice batch generation (network, personalized): <8s (95th percentile)
- Practice batch generation (network, generic): <5s (95th percentile)
- Tab switch to Practice: <100ms
- Question navigation: <50ms (instant)
- Cache hit rate: >60% (1-hour TTL)
- UI responsiveness: 60 FPS maintained

---

## Security & Privacy

### Authentication
- All Firebase Functions require valid Firebase Auth token
- Token verified on every request
- Invalid/expired tokens return 401 Unauthorized

### Rate Limiting
- Practice batch requests: 5 per minute per user
- Implemented in Firebase Functions
- Rate limit state stored in Firestore `rateLimits` collection
- Prevents abuse and controls OpenAI costs

### Data Privacy
- Practice data is per-user (not shared between users)
- Conversation analysis happens server-side only
- No message content stored in practice cache
- Only statistical patterns and generated items cached
- User can't see other users' practice data

### Content Safety
- Validate Georgian script only (Unicode U+10A0 to U+10FF)
- Filter offensive/inappropriate words server-side
- Sanitize all user inputs before GPT-4 analysis
- Rate limit prevents prompt injection attacks

---

## Deployment & Rollout

### Phase 1: Development & Testing (Week 1-2)
1. Implement iOS models, services, and views
2. Implement Firebase Cloud Functions
3. Unit tests and integration tests
4. Internal testing with team (5-10 users)

### Phase 2: Staging Deployment (Week 3)
1. Deploy to Firebase staging environment
2. Test with 10-20 beta users
3. Monitor performance metrics and costs
4. Fix critical bugs and polish UI

### Phase 3: Production Rollout (Week 4)
1. Deploy to production with feature flag disabled
2. Enable for 10% of users (A/B test)
3. Monitor analytics, performance, costs
4. Gradually increase to 25%, 50%, 100%
5. Full rollout if metrics look good

### Feature Flags
```swift
// iOS
UserDefaults.standard.bool(forKey: "practiceFeatureEnabled")

// Firebase Functions
functions.config().features.practice_enabled === 'true'
```

---

## Cost Estimation

### OpenAI API Costs

**GPT-4 Pricing**:
- Input: $3.00 per 1M tokens
- Output: $15.00 per 1M tokens

**Personalized Practice** (per request):
- Input: ~800 tokens (prompt + 50 messages context)
- Output: ~600 tokens (15 practice items + explanations)
- Cost per request: $0.0114
- With 60% cache hit: $0.00456 effective

**Generic Practice** (per request):
- Input: ~200 tokens (prompt only)
- Output: ~600 tokens (15 practice items)
- Cost per request: $0.0096
- With 60% cache hit: $0.00384 effective

**Monthly Cost** (1000 active users):
- Assume 70% personalized, 30% generic
- Average 5 batch requests per user per month
- Personalized: 1000 × 0.7 × 5 × $0.00456 = $15.96
- Generic: 1000 × 0.3 × 5 × $0.00384 = $5.76
- **Total: ~$22/month per 1000 users**

**Note**: This is significantly more expensive than AI V3 features due to GPT-4 (not mini). Consider:
- Aggressive caching (1-hour TTL helps)
- Monitor costs closely during rollout
- Consider switching to gpt-4o-mini if quality is acceptable
- Potential savings: gpt-4o-mini would reduce costs by ~90%

### Firebase Costs
- Firestore reads/writes: Minimal (1-hour cache)
- Cloud Functions invocations: ~5K/month/1000 users
- Bandwidth: Minimal (JSON responses small)
- **Estimated: <$5/month per 1000 users**

---

## Success Metrics

### Engagement
- % of users who open Practice tab
- Avg practice batches completed per user per week
- Practice session duration
- Completion rate (% who finish all 15 questions)
- Restart rate vs new batch rate

### Performance
- P50, P95, P99 latency for batch generation
- Cache hit rates
- Error rates
- Tab switch performance

### Learning Impact
- Letter accuracy improvement over time (before/after)
- Reduction in problematic letter usage
- Increase in Georgian message confidence
- User-reported helpfulness (optional in-app survey)

### Target Goals (3 months post-launch)
- 30% of users try Practice tab
- 15% of users complete ≥1 batch per week
- <8s P95 personalized batch latency
- <5s P95 generic batch latency
- >60% cache hit rate
- <2% error rate
- 70% completion rate (finish all 15 questions)

---

## Setup Instructions

### OpenAI API Configuration

1. **Get OpenAI API Key**:
   - Go to https://platform.openai.com/api-keys
   - Create new secret key
   - Copy key (starts with `sk-`)

2. **Set Firebase Function Config**:
   ```bash
   # Development
   firebase functions:config:set openai.key="sk-..."
   
   # Or use environment variable
   export OPENAI_API_KEY="sk-..."
   ```

3. **Enable GPT-4 Access**:
   - Ensure OpenAI account has GPT-4 API access
   - May require payment method on file
   - Check quota limits

### Firebase Setup

1. **Deploy Functions**:
   ```bash
   cd functions
   npm install
   firebase deploy --only functions:generatePractice
   ```

2. **Create Firestore Indexes**:
   ```bash
   firebase deploy --only firestore:indexes
   ```

3. **Set Security Rules**:
   - Update Firestore rules to allow practiceCache reads/writes
   - Ensure user can only access their own practice data

### iOS Setup

1. **Enable Feature Flag**:
   ```swift
   // For testing, enable immediately
   UserDefaults.standard.set(true, forKey: "practiceFeatureEnabled")
   ```

2. **Test Offline Handling**:
   - Disable network in simulator
   - Verify offline message appears

3. **Test with Different User States**:
   - New user (0 messages) → generic practice
   - User with 10 messages → generic practice
   - User with 30 messages → personalized practice

### Monitoring Setup

1. **Firebase Console**:
   - Monitor function invocations
   - Check error rates
   - Review latency metrics

2. **OpenAI Dashboard**:
   - Monitor token usage
   - Track costs daily
   - Set up billing alerts

3. **Analytics**:
   - Verify events are firing
   - Create dashboards for key metrics
   - Set up alerts for anomalies

---

## Tool Use Integration

### WebSocket-to-WebSocket Workflow

**Current Implementation**: Firebase HTTPS Callable (onCall)

**Future Optimization** (if <8s target not met):
- Convert to SSE (Server-Sent Events) like translation feature
- Stream practice items as they're generated
- Show first 5 questions immediately while generating remaining 10
- Perceived latency: ~3s instead of 8s

**Implementation**:
```javascript
// functions/practiceFunction.js
exports.generatePracticeStream = functions
  .runWith({ timeoutSeconds: 60, memory: '1GB' })
  .https.onRequest(async (req, res) => {
    res.set({
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive'
    });
    
    // Stream practice items as generated
    // Client receives and displays incrementally
  });
```

### Response Time Targets

- **Simple commands** (N/A for this feature): <2s
- **Translation/suggestions** (existing features): <8s
- **Practice batch generation**: <8s (95th percentile)
  - Personalized: <8s with RAG
  - Generic: <5s (simpler prompt)
  - Cached: <200ms

---

## Future Enhancements

### Practice Improvements
- **Difficulty Levels**: Easy/Medium/Hard based on user progress
- **Spaced Repetition**: Show problematic letters more frequently
- **Progress Tracking**: Long-term statistics (optional persistence)
- **Audio Pronunciation**: Play word pronunciation on reveal
- **Hints**: "Show similar word" or "Show usage example"

### Gamification (Optional)
- **Streaks**: Track consecutive days practicing
- **Achievements**: "Completed 10 batches", "Perfect score"
- **Leaderboard**: Compare with friends (opt-in)
- **Points System**: Earn points for correct answers

### Advanced Analysis
- **Context-Aware Patterns**: Analyze letter confusion in specific word types
- **Keyboard Proximity**: Detect typos vs genuine confusion
- **Learning Velocity**: Adapt difficulty based on improvement rate
- **Multi-Language**: Extend to other language pairs

### Social Features
- **Challenge Friends**: Send practice batch to friend
- **Shared Batches**: Practice together in real-time
- **Teacher Mode**: Create custom practice for specific users

---

## Implementation Notes

### Georgian Letter Confusion Patterns

Common confusions to include in wrong options:
- **ი (i) ↔ უ (u)**: Similar sounds, different positions
- **ა (a) ↔ ო (o)**: Vowel confusion
- **ე (e) ↔ ი (i)**: Similar sounds
- **ბ (b) ↔ დ (d)**: Visually similar
- **გ (g) ↔ ყ (q')**: Similar shapes
- **პ (p) ↔ ფ (p')**: Aspiration confusion
- **თ (t') ↔ ტ (t)**: Aspiration confusion
- **ს (s) ↔ შ (sh)**: Similar sounds

### Visually Similar Letters

For wrong options based on visual similarity:
- **ა ↔ ო** (circular base)
- **ბ ↔ დ ↔ ო** (rounded shapes)
- **გ ↔ ყ** (similar curves)
- **ე ↔ ვ** (similar strokes)
- **თ ↔ ტ** (similar structure)
- **მ ↔ შ** (multiple strokes)

### Word Selection Strategy

GPT-4 should prioritize:
1. **User's actual words**: Words they've typed (builds relevance)
2. **Conversation topics**: Related vocabulary (e.g., if discussing food, use food words)
3. **Frequency**: More common words first
4. **Difficulty balance**: Mix easy and challenging words

### Explanation Templates

Keep explanations concise and helpful:
- "Common in verb endings"
- "Typical for this word family"
- "Used in formal contexts"
- "Greeting word - 'hello'"
- "Often confused with [letter]"
- "Position matters in this case"

---

## Architecture Alignment

This feature follows existing patterns:

**Similar to GeoSuggestionService**:
- Firebase Cloud Function callable
- RAG with conversation context
- Caching strategy (Firestore + local)
- Throttling and rate limiting
- Analytics events
- Offline handling

**Similar to DefinitionService**:
- User-initiated (not automatic)
- OpenAI integration with structured prompts
- JSON response parsing
- Error handling and retries

**Similar to EnglishTranslationSuggestionService**:
- Message count threshold logic
- Generic vs personalized paths
- User tracking and state management

**UI Pattern**: New tab (like existing Chats/Profile)

**Service Pattern**: Singleton with @MainActor

**ViewModel Pattern**: ObservableObject with @Published state

---

## Risk Mitigation

### High Costs
- **Risk**: GPT-4 is expensive (~10x more than gpt-4o-mini)
- **Mitigation**: 
  - Aggressive caching (1-hour TTL)
  - Rate limiting (5 req/min)
  - Monitor costs daily during rollout
  - Feature flag for quick disable if needed
  - Consider gpt-4o-mini if acceptable quality

### Slow Response Times
- **Risk**: 8s feels slow for interactive feature
- **Mitigation**:
  - Cache hits are fast (<200ms)
  - Show engaging loading animation
  - Consider SSE streaming for incremental display
  - Set timeout at 15s with clear error message

### Poor Quality Generic Practice
- **Risk**: New users get low-quality practice
- **Mitigation**:
  - Curate common Georgian words in prompt
  - Test thoroughly with beginners
  - Consider pre-generated static batches as fallback
  - Collect feedback from new users

### Privacy Concerns
- **Risk**: Users worried about message analysis
- **Mitigation**:
  - Clear privacy statement in UI
  - Analysis happens server-side only
  - No message content cached
  - Per-user isolation enforced
  - Optional opt-out setting

### Limited Data for Personalization
- **Risk**: 50 messages may not reveal patterns
- **Mitigation**:
  - 20-message threshold prevents poor analysis
  - Generic practice is still valuable
  - Encourage users to chat more (gamification)
  - Combine patterns across conversations

---

## Success Criteria

This feature is successful if:

1. **Adoption**: ≥30% of users try Practice tab
2. **Engagement**: ≥15% complete ≥1 batch per week
3. **Performance**: <8s P95 latency, >60% cache hit rate
4. **Quality**: Users report practice is helpful (survey)
5. **Cost**: Costs scale linearly with users (<$30/1000 users)
6. **Reliability**: <2% error rate, graceful degradation
7. **Learning Impact**: Measurable improvement in letter accuracy

---

## Conclusion

The Context-Aware Smart Practice feature leverages OpenAI GPT-4 with RAG to provide personalized Georgian spelling exercises. By analyzing user conversation patterns and generating targeted practice, it addresses a key learning challenge: letter confusion and placement.

The implementation follows established architecture patterns, includes robust caching and error handling, and targets <8s response times. With proper monitoring and cost controls, this feature will enhance user learning while maintaining system reliability and budget constraints.

