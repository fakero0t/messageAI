# AI V4 Practice Feature - Setup Instructions

## ✅ Implementation Complete

All components for the Context-Aware Smart Practice feature have been implemented:

### iOS Components Created
- ✅ `Models/PracticeItem.swift` - Practice question model
- ✅ `Services/PracticeService.swift` - Firebase integration service
- ✅ `ViewModels/PracticeViewModel.swift` - Practice state management
- ✅ `Views/Practice/PracticeView.swift` - Main practice interface
- ✅ `Views/Practice/PracticeQuestionCard.swift` - Question display
- ✅ `Views/Practice/PracticeResultCard.swift` - Result feedback
- ✅ `Views/Practice/PracticeCompletionView.swift` - Completion screen
- ✅ `Views/MainView.swift` - Updated with Practice tab

### Firebase Components Created
- ✅ `functions/practiceFunction.js` - GPT-4 practice generation
- ✅ `functions/index.js` - Updated with practice export

---

## 🚀 Deployment Steps

### 1. Deploy Firebase Functions

```bash
cd functions
npm install
firebase deploy --only functions:generatePractice
```

### 2. Configure OpenAI API Key

If not already configured:

```bash
firebase functions:config:set openai.key="sk-your-key-here"
```

Or use environment variable:
```bash
export OPENAI_API_KEY="sk-your-key-here"
```

### 3. Update Firestore Indexes

Add to `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "practiceCache",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" }
      ]
    }
  ]
}
```

Deploy:
```bash
firebase deploy --only firestore:indexes
```

### 4. Update Firestore Security Rules

Add to `firestore.rules`:

```javascript
// Practice cache collection
match /practiceCache/{userId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}

// Rate limits collection
match /rateLimits/{docId} {
  allow read, write: if request.auth != null;
}
```

Deploy:
```bash
firebase deploy --only firestore:rules
```

---

## 🧪 Testing

### 1. Build and Run iOS App

```bash
open swift_demo.xcodeproj
# Select device/simulator
# Press Cmd+R to build and run
```

### 2. Test Scenarios

**New User (<20 messages)**:
1. Create a new user account
2. Navigate to Practice tab
3. Verify: Generic practice is generated
4. Complete a few questions
5. Test "Generate New Practice" button
6. Test "Restart This Batch" button

**Active User (≥20 messages)**:
1. Use existing account with conversations
2. Send at least 20 Georgian messages
3. Navigate to Practice tab
4. Verify: Personalized practice is generated
5. Check that practice uses words from your messages
6. Complete all 15 questions
7. Verify completion screen appears

**Offline Mode**:
1. Disable network in simulator
2. Navigate to Practice tab
3. Verify: Offline error message appears
4. Re-enable network
5. Tap "Try Again"
6. Verify: Practice loads successfully

**Rate Limiting**:
1. Generate new practice 5 times rapidly
2. Verify: 6th attempt shows rate limit error
3. Wait 1 minute
4. Verify: Can generate again

---

## 📊 Monitoring

### Check Firebase Console

**Functions**:
- Monitor `generatePractice` invocations
- Check latency (should be <8s P95)
- Review error rates

**Firestore**:
- Check `practiceCache` collection
- Verify TTL cleanup (1 hour)
- Monitor `rateLimits` collection

**OpenAI Dashboard**:
- Monitor GPT-4 token usage
- Track costs (expect ~$22/month per 1000 active users)
- Set billing alerts

### Analytics Events

Monitor these events in your analytics:
- `practice_tab_opened`
- `practice_batch_requested`
- `practice_batch_generated`
- `practice_question_answered`
- `practice_batch_completed`

---

## 🎯 Feature Flags

Enable/disable feature:

```swift
// iOS
UserDefaults.standard.set(true, forKey: "practiceFeatureEnabled")
```

```javascript
// Firebase Functions
functions.config().features.practice_enabled === 'true'
```

---

## 🐛 Troubleshooting

### Practice Not Loading

1. Check Firebase auth: User must be signed in
2. Check network: Must be online
3. Check OpenAI key: Must be configured
4. Check function logs: `firebase functions:log`

### Generic Practice When Should Be Personalized

1. Verify user has ≥20 sent messages
2. Check messages contain Georgian script
3. Review function logs for message count

### Slow Generation Times

1. Check OpenAI status page
2. Monitor function timeout (30s max)
3. Consider enabling caching more aggressively
4. Check network latency

### Rate Limit Issues

1. Check `rateLimits` collection in Firestore
2. Verify 1-minute window resets correctly
3. Adjust max requests if needed (currently 5/min)

---

## 💰 Cost Optimization

### Current Costs
- **GPT-4**: ~$22/month per 1000 users
- **Firebase**: <$5/month per 1000 users
- **Total**: ~$27/month per 1000 users

### Optimization Options

1. **Increase Cache TTL**: 
   - Change from 1 hour to 24 hours
   - Reduces GPT-4 calls significantly
   - Trade-off: Less fresh personalization

2. **Switch to GPT-4o-mini**:
   - Change model in `practiceFunction.js`
   - 90% cost reduction
   - Trade-off: Lower analysis quality

3. **Pre-generate Static Batches**:
   - Create 50+ generic practice batches
   - Serve randomly for new users
   - Eliminates GPT-4 calls for <20 message users

---

## 📝 Next Steps

### Recommended Enhancements

1. **Add Analytics Integration**:
   - Replace console.log with actual analytics service
   - Track user engagement metrics
   - Monitor learning progress

2. **Add Feature Flag UI**:
   - Toggle in Settings tab
   - User preference for practice difficulty
   - Opt-out option

3. **Improve Offline Support**:
   - Cache last generated batch locally
   - Allow offline practice with cached batch
   - Show "offline mode" indicator

4. **Add Progress Tracking**:
   - Optional persistence of answers
   - Show correct/incorrect stats
   - Track improvement over time

5. **Enhance UI**:
   - Add animations for transitions
   - Confetti on completion
   - Sound effects (optional)

---

## 🎉 You're All Set!

The Context-Aware Smart Practice feature is fully implemented and ready to deploy. Follow the steps above to get it running in production.

For questions or issues, refer to:
- `ai_v4_prd.md` - Complete feature specification
- Firebase Console logs
- OpenAI Dashboard

Happy practicing! 🇬🇪

