# AI V3 Setup Instructions

## Quick Start Guide

Follow these steps to deploy and test the new AI V3 features.

---

## Step 1: Firebase Configuration

### Set OpenAI API Key

```bash
cd /Users/ary/Desktop/swift_demo/functions

# Set OpenAI API key in Firebase config
firebase functions:config:set openai.key="YOUR_OPENAI_API_KEY_HERE"

# Verify it's set
firebase functions:config:get
```

**Get your OpenAI API key:**
1. Go to https://platform.openai.com/api-keys
2. Create a new secret key
3. Copy the key (starts with `sk-proj-...`)

---

## Step 2: Deploy Firebase Functions

```bash
cd /Users/ary/Desktop/swift_demo/functions

# Install dependencies (if not already done)
npm install

# Deploy the new functions
firebase deploy --only functions:getWordDefinition,functions:suggestEnglishToGeorgian

# Expected output:
# ✔  functions[us-central1-getWordDefinition]: Successful create operation
# ✔  functions[us-central1-suggestEnglishToGeorgian]: Successful create operation
```

### Verify Deployment

```bash
# Check function logs
firebase functions:log --only getWordDefinition

# Test the endpoint (will require auth token)
curl -X POST https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/getWordDefinition \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"word":"გამარჯობა","conversationId":"test","fullContext":"გამარჯობა!","timestamp":1234567890}'
```

---

## Step 3: Update iOS Project

### Update Firebase Project ID

**File:** `swift_demo/Services/DefinitionService.swift`

```swift
// Line ~216: Update your Firebase project ID
let projectId = "YOUR_FIREBASE_PROJECT_ID"  // Replace this!
```

### Build and Run

```bash
# Open Xcode
open /Users/ary/Desktop/swift_demo/swift_demo.xcodeproj

# Build and run on simulator or device
# Cmd + R
```

---

## Step 4: Testing Feature 1 (Word Definitions)

### Test Definition Lookup

1. **Open the app** and navigate to any conversation
2. **Send a Georgian message**: Type "გამარჯობა!" and send
3. **Long-press the word** "გამარჯობა" in the message bubble
4. **Verify**:
   - Modal appears with loading state
   - Definition shows: "A greeting meaning 'hello' or 'hi'..."
   - Example sentence in Georgian appears
   - Modal can be dismissed by tapping outside

### Test Caching

1. **Long-press the same word** again
2. **Verify**:
   - Modal appears instantly (no loading)
   - Same definition displayed
   - Shows "Cached offline" indicator

### Test Offline Mode

1. **Turn off WiFi and cellular** on device/simulator
2. **Long-press a NEW Georgian word** (not cached)
3. **Verify**:
   - Error modal appears
   - Message: "You're offline. Definition lookup requires internet connection."
   - Can dismiss modal

---

## Step 5: Testing Feature 2 (English Suggestions)

### Test English Word Tracking

1. **Send messages with English words**:
   ```
   Send: "hello everyone"
   Send: "hello there"
   Send: "hello friend"
   ... (send "hello" 14+ times in different messages)
   ```

2. **Wait for suggestion** (after 3 messages since last suggestion)

3. **Type a new message** containing "hello"

4. **Verify**:
   - Suggestion bar appears above keyboard
   - Message: "You use 'hello' often. Try using one of these Georgian translations!"
   - Shows 3 Georgian options with glosses

### Test Smart Replace

1. **Type**: "hello world"
2. **Accept suggestion** (tap "Use this")
3. **Verify**:
   - "hello" replaced with Georgian word
   - Result: "გამარჯობა world" (or similar)
   - Undo button appears

### Test Priority (Georgian over English)

1. **Use a Georgian word frequently** (e.g., "კარგი" 3+ times)
2. **Use an English word frequently** (e.g., "good" 14+ times)
3. **Type message** with "კარგი"
4. **Verify**:
   - Only Georgian suggestions show (priority)
   - English suggestions DON'T show simultaneously

---

## Step 6: Monitor Analytics

### Check Firestore

```bash
# View definition cache
firebase firestore:get definitionCache --limit 10

# View English translation cache
firebase firestore:get englishTranslationCache --limit 10

# Check rate limits
firebase firestore:get rateLimits --limit 10
```

### Check Function Logs

```bash
# Real-time logs
firebase functions:log --only getWordDefinition,suggestEnglishToGeorgian

# Look for these events:
# - definition_cache_hit
# - definition_generated
# - english_translation_cache_hit
# - english_translation_generated
```

---

## Step 7: Performance Verification

### Check Latencies

**Definition Lookup:**
- Target: <2s for first lookup
- Target: <50ms for cached lookups

**English Suggestions:**
- Target: <3s for first fetch
- Target: <100ms for cached suggestions

### Monitor in Xcode Console

Look for these log lines:
```
✅ [DefinitionService] Definition loaded (latency: 1450ms)
✅ [DefinitionService] Cache hit for word: გამარჯობა
```

---

## Troubleshooting

### Issue: "Firebase Function not found"

**Solution:**
```bash
# Redeploy functions
firebase deploy --only functions

# Check function list
firebase functions:list
```

### Issue: "OpenAI API error"

**Solution:**
```bash
# Verify API key is set
firebase functions:config:get

# Check your OpenAI account has credits
# https://platform.openai.com/account/usage

# Test API key manually
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer YOUR_API_KEY"
```

### Issue: "Suggestions not showing"

**Check:**
1. Word frequency threshold met? (14 uses in 7 days)
2. Throttling active? (1 per 3 messages, 24h cooldown)
3. Georgian suggestions showing instead? (they have priority)

**Debug:**
```swift
// Add to GeoSuggestionBar.checkForSuggestions()
print("🔍 Checking suggestions...")
print("   Georgian trigger word: \(suggestionService.shouldShowSuggestion(for: messageText))")
print("   English trigger word: \(englishSuggestionService.shouldShowEnglishSuggestion(for: messageText, userId: userId))")
```

### Issue: "Definition modal not showing"

**Check:**
1. Is text Georgian? (only works on Georgian words)
2. Long-press duration correct? (0.5 seconds)
3. Network connectivity? (required for first lookup)

**Debug:**
```swift
// Add to MessageBubbleView.handleLongPress()
print("🔍 Long-press detected")
print("   Extracted word: \(extractedWord)")
print("   Network connected: \(networkMonitor.isConnected)")
```

---

## Cost Monitoring

### OpenAI Usage

**Check usage:**
1. Go to https://platform.openai.com/account/usage
2. Monitor daily token usage
3. Set up billing alerts

**Expected costs (1000 users):**
- Definitions: ~$0.54/month
- Translations: ~$0.39/month
- **Total: ~$1/month per 1000 users**

### Firebase Costs

**Cloud Functions:**
- Invocations: Included in free tier (125K/month)
- Compute time: Minimal (sub-second requests)

**Firestore:**
- Reads: Mostly cached (minimal cost)
- Writes: Only for cache updates

---

## Feature Flags (Optional)

To enable gradual rollout, add feature flags:

```swift
// In AppDelegate or similar
UserDefaults.standard.set(true, forKey: "definitionLookupEnabled")
UserDefaults.standard.set(true, forKey: "englishSuggestionsEnabled")

// In DefinitionService
guard UserDefaults.standard.bool(forKey: "definitionLookupEnabled") else {
    throw DefinitionError.featureDisabled
}

// In EnglishTranslationSuggestionService  
guard UserDefaults.standard.bool(forKey: "englishSuggestionsEnabled") else {
    return nil
}
```

---

## Production Checklist

Before releasing to users:

- [ ] OpenAI API key set in Firebase
- [ ] Functions deployed to production
- [ ] Firebase project ID updated in iOS code
- [ ] Tested on physical device (not just simulator)
- [ ] Tested with real OpenAI API (not mock)
- [ ] Verified offline behavior
- [ ] Verified caching works correctly
- [ ] Monitored initial costs (first 100 users)
- [ ] Set up alerts for unusual usage
- [ ] Analytics events firing correctly
- [ ] Rate limiting tested and working
- [ ] Error handling tested (network issues, API failures)

---

## Support

If you encounter issues:

1. **Check logs:** `firebase functions:log`
2. **Check Xcode console:** Look for [DefinitionService] and [EnglishSuggestion] logs
3. **Verify network:** Definitions require internet for first lookup
4. **Check thresholds:** English suggestions need 14 uses in 7 days
5. **Test in isolation:** Try each feature separately

---

## Success! 🎉

Both features are now live:
- 👆 Long-press Georgian words for definitions
- 💬 Smart English→Georgian translation suggestions

Users will love the natural language learning experience!

