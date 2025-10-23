# Georgian Learning Mode Toggle - Product Requirements Document

## Overview

This feature provides users with a master toggle to enable or disable Georgian Learning Mode. When disabled (default), users experience a standard messaging app. When enabled, they gain access to Georgian language learning features including practice exercises and intelligent vocabulary suggestions.

## Business Goals

- **Flexible UX**: Allow users to opt-in to learning features without overwhelming non-learners
- **Device Sync**: Ensure preference persists across all user devices
- **Instant Updates**: No app restart required when toggling the setting
- **Clean Architecture**: Single source of truth stored in user profile

## User Stories

### As a new user
- I want Georgian Learning Mode OFF by default so I can use the app as a regular messaging platform
- I want to easily enable learning features when I'm ready to start learning Georgian

### As a Georgian learner
- I want to enable Georgian Learning Mode to access practice exercises and vocabulary suggestions
- I want my preference synced across my iPhone and iPad
- I want changes to take effect immediately without restarting the app

### As a casual user
- I want to disable Georgian Learning Mode to hide learning features I don't use
- I want the Practice tab to disappear when I disable the mode

## Technical Implementation

### 1. Data Model

**File**: `swift_demo/Models/User.swift`

```swift
struct User: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let username: String
    let displayName: String
    var online: Bool = false
    var lastSeen: Date?
    var profileImageUrl: String?
    var georgianLearningMode: Bool = false  // NEW: Default OFF
    // ...
}
```

**Storage**: Firebase Firestore `users/{userId}` collection
**Default**: `false` (OFF by default for all new and existing users)
**Migration**: Graceful - existing users without the field default to `false`

### 2. Service Layer

**File**: `swift_demo/Services/UserService.swift`

New method to update learning mode preference:

```swift
func updateGeorgianLearningMode(userId: String, enabled: Bool) async throws {
    // 1. Update Firestore document
    try await db.collection("users").document(userId).updateData([
        "georgianLearningMode": enabled
    ])
    
    // 2. Update local currentUser object for immediate UI refresh
    if var currentUser = AuthenticationService.shared.currentUser,
       currentUser.id == userId {
        currentUser.georgianLearningMode = enabled
        await MainActor.run {
            AuthenticationService.shared.currentUser = currentUser
        }
    }
}
```

**Real-time Sync**: Existing `AuthenticationService` with `@Published var currentUser` handles cross-device synchronization automatically via Firestore snapshot listeners.

### 3. User Interface

#### Settings Toggle

**Location**: Profile → Georgian Learning (replaces old "Georgian Vocabulary Suggestions" section)

**File**: `swift_demo/Views/MainView.swift` (ProfileView)

```swift
Section("Georgian Learning") {
    Toggle("Georgian Learning Mode", isOn: Binding(
        get: { currentUser?.georgianLearningMode ?? false },
        set: { enabled in
            guard let userId = currentUser?.id else { return }
            Task {
                try? await UserService.shared.updateGeorgianLearningMode(
                    userId: userId, 
                    enabled: enabled
                )
                if !enabled {
                    // Reset services when disabling
                    GeoSuggestionService.shared.resetSession()
                    EnglishTranslationSuggestionService.shared.resetSession()
                }
            }
        }
    ))
    
    Text("Enable to access practice exercises and receive Georgian vocabulary suggestions while chatting")
        .font(.caption)
        .foregroundColor(.secondary)
}
```

#### Conditional Practice Tab

**File**: `swift_demo/Views/MainView.swift` (MainView)

```swift
var body: some View {
    let isLearningModeEnabled = AuthenticationService.shared.currentUser?.georgianLearningMode ?? false
    
    ZStack {
        TabView(selection: $selectedTab) {
            ConversationListView(...)
                .tabItem { Label("Chats", systemImage: "message") }
                .tag(0)
            
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(1)
            
            // Conditionally show Practice tab
            if isLearningModeEnabled {
                PracticeView()
                    .tabItem { Label("Practice", systemImage: "book.fill") }
                    .tag(2)
            }
        }
    }
}
```

#### Suggestion Bar Gating

**File**: `swift_demo/Views/Components/GeoSuggestionBar.swift`

Both Georgian word suggestions and English→Georgian translation suggestions are controlled by the master toggle:

```swift
var body: some View {
    let isEnabled = AuthenticationService.shared.currentUser?.georgianLearningMode ?? false
    
    Group {
        if !isEnabled {
            EmptyView()
        } else {
            // Show suggestions, loading states, etc.
        }
    }
}
```

## Feature Behavior

### When Georgian Learning Mode is OFF (Default)
- ❌ Practice tab is hidden from main TabView
- ❌ No Georgian word suggestions appear above keyboard
- ❌ No English→Georgian translation suggestions
- ❌ No suggestion API calls made
- ✅ Full messaging functionality available
- ✅ Clean, distraction-free chat experience

### When Georgian Learning Mode is ON
- ✅ Practice tab appears as third tab
- ✅ Georgian word suggestions shown based on conversation history
- ✅ English→Georgian translation suggestions for frequently used English words
- ✅ Real-time vocabulary tracking
- ✅ Context-aware practice generation
- ✅ All learning analytics active

### Toggle Interaction
1. User opens Profile settings
2. User taps "Georgian Learning Mode" toggle
3. Request sent to Firebase Firestore
4. Local user object updated immediately
5. UI updates instantly (tab appears/disappears, suggestions enable/disable)
6. Service sessions reset when disabling (clears cached state)
7. Change syncs to other devices automatically

## Data Flow

```
User Toggles Switch
    ↓
ProfileView Binding.set
    ↓
UserService.updateGeorgianLearningMode()
    ↓
Firebase Firestore Update
    ↓
AuthenticationService.currentUser updated (@Published)
    ↓
SwiftUI Views Observe Change
    ↓
UI Updates Instantly
    ↓
Other Devices Receive Firestore Update
    ↓
Their UI Updates Automatically
```

## Privacy & Security

- **No New Data Collection**: Only stores boolean preference
- **User Control**: Feature fully opt-in with clear description
- **Data Location**: Stored in user's own Firestore document (`users/{userId}`)
- **Existing Privacy**: All existing Georgian suggestion privacy measures remain (word hashing, filtered content, etc.)

## Edge Cases

### Nil User Handling
- All checks use `currentUser?.georgianLearningMode ?? false`
- Defaults to OFF if user object unavailable
- No crashes if Firebase connection lost

### Missing Field in Firestore
- Existing users without field default to `false`
- No migration script needed
- Field added on first toggle interaction

### Service Reset
- When disabling, both `GeoSuggestionService` and `EnglishTranslationSuggestionService` reset their sessions
- Clears cached suggestions and state
- Prevents stale suggestions on re-enable

### Tab Selection
- If user is on Practice tab (tag 2) when they disable mode, tab automatically switches away
- SwiftUI handles this gracefully as conditional view disappears

## Testing Requirements

### Unit Tests
- [ ] User model encodes/decodes georgianLearningMode field
- [ ] UserService.updateGeorgianLearningMode updates Firestore
- [ ] UserService updates local currentUser object

### Integration Tests
- [ ] Toggle OFF by default for new users
- [ ] Toggle state persists after app restart
- [ ] Practice tab hidden when mode OFF
- [ ] Practice tab visible when mode ON
- [ ] Suggestion bar hidden when mode OFF
- [ ] Suggestion bar visible when mode ON
- [ ] Services reset when toggling OFF

### E2E Tests
- [ ] Enable mode on Device A, verify tab appears
- [ ] Verify change syncs to Device B automatically
- [ ] Disable mode on Device B, verify tab disappears on both devices
- [ ] Send messages with mode ON, verify suggestions appear
- [ ] Toggle OFF mid-chat, verify suggestions disappear immediately
- [ ] Toggle back ON, verify suggestions resume

### Manual Testing
- [ ] Toggle responds instantly without lag
- [ ] No app restart required for changes
- [ ] Practice tab animates smoothly in/out
- [ ] No console errors when toggling
- [ ] Clear description helps users understand feature

## Success Metrics

### Adoption Metrics
- **Activation Rate**: % of users who enable Georgian Learning Mode
- **Time to Activation**: Days between signup and first enable
- **Retention**: % of users who keep it enabled after 7/30 days

### Engagement Metrics (When Mode ON)
- **Practice Usage**: Sessions per week
- **Suggestion CTR**: Click-through rate on vocabulary suggestions
- **Learning Consistency**: Days with practice activity

### UX Metrics
- **Toggle Response Time**: <200ms from tap to UI update
- **Sync Latency**: <3s from Device A toggle to Device B update
- **Error Rate**: <0.1% of toggle operations fail

## Future Enhancements

### Phase 2 (Optional)
- **Per-Chat Toggle**: Disable suggestions in specific conversations
- **Learning Level**: Beginner/Intermediate/Advanced modes
- **Practice Reminders**: Smart notifications for practice sessions
- **Progress Dashboard**: Vocabulary growth, practice streaks
- **Offline Mode**: Cache practice questions for offline use

### Analytics Enhancement
- Track toggle events: `user_enabled_learning_mode`, `user_disabled_learning_mode`
- Segment users by mode status in analytics
- A/B test default state (OFF vs ON for cohorts)

## Migration Notes

### Deprecation of Old Toggle
- **Old**: `UserDefaults.standard.bool(forKey: "geoSuggestionsDisabled")`
- **New**: `User.georgianLearningMode` (Firestore-backed)
- **Benefit**: Device sync, no local state issues
- **Cleanup**: Remove all `geoSuggestionsDisabled` references (completed in implementation)

### User Communication
- **In-App**: Toggle description clearly explains what features are enabled
- **No Announcement Needed**: Existing users default to OFF (no behavior change)
- **Discoverable**: Placed prominently in Profile settings

## Implementation Status

✅ **Completed**
1. User model updated with `georgianLearningMode` field
2. UserService method `updateGeorgianLearningMode` added
3. ProfileView toggle replaced with master toggle
4. MainView conditionally shows Practice tab
5. GeoSuggestionBar checks User model instead of UserDefaults
6. Service reset logic implemented
7. Real-time sync via existing architecture

## Related Documentation

- **Georgian Suggestions**: See `GEO_SUGGESTIONS_COMPLETE.md` for full feature spec
- **Practice System**: See `ai_v4_prd.md` for practice feature details
- **English Suggestions**: See `ai_v3_prd.md` for English→Georgian translation suggestions
- **User Model**: See `swift_demo/Models/User.swift` for complete User schema

## Vue/TypeScript Analogy

For web developers familiar with Vue.js, this implementation is analogous to:

```typescript
// Pinia store (like AuthenticationService.shared.currentUser)
export const useUserStore = defineStore('user', {
  state: () => ({
    currentUser: null as User | null
  }),
  
  actions: {
    async updateGeorgianLearningMode(enabled: boolean) {
      // Update Firestore
      await updateDoc(doc(db, 'users', this.currentUser.id), {
        georgianLearningMode: enabled
      })
      
      // Update local state (triggers reactive updates)
      this.currentUser.georgianLearningMode = enabled
      
      if (!enabled) {
        geoSuggestionService.resetSession()
        englishSuggestionService.resetSession()
      }
    }
  }
})

// In component (like MainView)
const userStore = useUserStore()
const showPracticeTab = computed(() => 
  userStore.currentUser?.georgianLearningMode ?? false
)

// In template
<TabView>
  <TabPanel title="Chats">...</TabPanel>
  <TabPanel title="Profile">...</TabPanel>
  <TabPanel v-if="showPracticeTab" title="Practice">...</TabPanel>
</TabView>

// Suggestion component (like GeoSuggestionBar)
const isEnabled = computed(() => 
  userStore.currentUser?.georgianLearningMode ?? false
)

// Firestore real-time listener (like AuthenticationService)
onSnapshot(doc(db, 'users', userId), (snapshot) => {
  userStore.currentUser = snapshot.data() as User
  // Vue's reactivity automatically updates all components
})
```

The key similarity: One source of truth (`@Published currentUser` / Pinia store), reactive UI updates (SwiftUI / Vue), and real-time sync (Firestore listeners).

