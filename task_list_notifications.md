# In-App Notifications - Task List

## Overview
Implement real-time in-app notification banners and accurate unread message counts. See `message_plan.prd` for full technical specification.

---

## PR-1: In-App Notification Infrastructure
**Goal**: Create the core notification system (models, service, UI component) without modifying existing message flow.
**Branch**: `feature/in-app-notification-infrastructure`
**Estimated Time**: 3-4 hours

### Tasks

#### 1. Create InAppNotification Model
- [ ] Create file: `swift_demo/Models/InAppNotification.swift`
- [ ] Define struct with properties:
  - `id: String` (UUID)
  - `conversationId: String`
  - `senderName: String`
  - `messageText: String`
  - `isGroup: Bool`
  - `timestamp: Date`
- [ ] Conform to `Identifiable` and `Equatable`
- [ ] Add convenience initializer

#### 2. Create InAppNotificationManager Service
- [ ] Create file: `swift_demo/Services/InAppNotificationManager.swift`
- [ ] Implement as `@MainActor` `ObservableObject` singleton
- [ ] Add `@Published var currentNotification: InAppNotification?`
- [ ] Implement `show(_ notification: InAppNotification)` method
  - Cancel existing auto-dismiss task
  - Set currentNotification
  - Start new auto-dismiss task (3 seconds)
- [ ] Implement `dismiss()` method
  - Cancel auto-dismiss task
  - Clear currentNotification with animation
- [ ] Add property `autoDismissDelay: TimeInterval = 3.0`

#### 3. Create NotificationBannerView Component
- [ ] Create file: `swift_demo/Views/Components/NotificationBannerView.swift`
- [ ] Create SwiftUI view that:
  - Observes `InAppNotificationManager` via `@EnvironmentObject`
  - Only renders when `currentNotification` exists
  - Shows banner at top with:
    - Avatar circle (group icon or sender initial)
    - Sender name (with "Group: " prefix if group)
    - Message preview (2 line limit)
  - Uses `.transition(.move(edge: .top).combined(with: .opacity))`
  - Has white/system background with shadow
  - Padding for safe area
- [ ] Add tap gesture → dismiss and navigate to conversation
  - Post `.navigateToConversation` notification with conversationId
- [ ] Add swipe up gesture → dismiss
  - DragGesture detecting upward swipe (translation.height < -50)

#### 4. Integrate Banner into App Root
- [ ] Update `swift_demo/swift_demoApp.swift`:
  - Add `@StateObject private var inAppNotificationManager = InAppNotificationManager.shared`
  - Add to environment objects: `.environmentObject(inAppNotificationManager)`
- [ ] Update `swift_demo/Views/MainView.swift`:
  - Add `.overlay(alignment: .top)` to TabView
  - Place `NotificationBannerView()` in overlay
  - Ensure banner appears above all tabs

#### 5. Testing & Verification
- [ ] Build project - ensure no compile errors
- [ ] Add test button in ProfileView to trigger test notification:
  ```swift
  Button("Test In-App Banner") {
      let notification = InAppNotification(
          conversationId: "test-123",
          senderName: "Test User",
          messageText: "This is a test in-app notification!",
          isGroup: false
      )
      InAppNotificationManager.shared.show(notification)
  }
  ```
- [ ] Verify banner appears at top
- [ ] Verify auto-dismiss after 3 seconds
- [ ] Verify tap navigation triggers (may not navigate without real conversation)
- [ ] Verify swipe up dismisses
- [ ] Test with long sender names and message text
- [ ] Test group notification styling

**Deliverables**:
- 3 new files created
- 2 files modified (swift_demoApp.swift, MainView.swift)
- Notification banner system fully functional and testable
- No integration with message flow yet (isolated system)

---

## PR-2: Message Flow Integration & Unread Counts
**Goal**: Connect in-app notifications to message reception flow and implement unread count logic.
**Branch**: `feature/in-app-notification-integration`
**Estimated Time**: 3-4 hours
**Depends on**: PR-1 merged

### Tasks

#### 1. Update ChatViewModel Integration
- [ ] Open `swift_demo/ViewModels/ChatViewModel.swift`
- [ ] Locate `showNotificationForMessage(_ snapshot: MessageSnapshot)` method (line ~326)
- [ ] After existing system notification call, add in-app notification:
  ```swift
  // Create and show in-app notification
  Task { @MainActor in
      let inAppNotification = InAppNotification(
          conversationId: conversationId,
          senderName: senderName,
          messageText: snapshot.text,
          isGroup: isGroup
      )
      InAppNotificationManager.shared.show(inAppNotification)
  }
  ```
- [ ] Add unread count increment logic:
  ```swift
  // Increment unread count ONLY if user not viewing this conversation
  if notificationService.currentConversationId != conversationId {
      Task {
          try? await localStorage.incrementUnreadCount(conversationId: conversationId)
      }
  }
  ```
- [ ] Add debug logging for tracking

#### 2. Update ConversationListViewModel Integration
- [ ] Open `swift_demo/ViewModels/ConversationListViewModel.swift`
- [ ] Locate `showNotificationForMessage(_ snapshot: MessageSnapshot, conversationId: String)` method (line ~286)
- [ ] After fetching sender name, add in-app notification:
  ```swift
  // Show in-app notification
  let inAppNotification = InAppNotification(
      conversationId: conversationId,
      senderName: senderName,
      messageText: snapshot.text,
      isGroup: isGroup
  )
  InAppNotificationManager.shared.show(inAppNotification)
  ```
- [ ] Add unread count increment:
  ```swift
  // Increment unread count if user not in this conversation
  if NotificationService.shared.currentConversationId != conversationId {
      try? localStorage.incrementUnreadCount(conversationId: conversationId)
  }
  ```
- [ ] Update to call on MainActor
- [ ] Add debug logging

#### 3. Verify Unread Count Reset Logic
- [ ] Review `swift_demo/Views/Chat/ChatView.swift`
  - Confirm `onAppear` calls `viewModel.markMessagesAsRead()` ✓
  - Confirm `onAppear` sets `notificationService.currentConversationId` ✓
  - Confirm `onDisappear` clears `notificationService.currentConversationId` ✓
- [ ] Review `swift_demo/Services/ReadReceiptService.swift`
  - Confirm `markMessagesAsRead` calls `localStorage.resetUnreadCount()` ✓
- [ ] No changes needed - already implemented correctly

#### 4. UI Enhancement: Bold Unread Conversations (Optional)
- [ ] Open `swift_demo/Views/Conversations/ConversationRowView.swift`
- [ ] Update conversation name Text view (line ~42):
  ```swift
  Text(conversationDetail.displayName)
      .font(.headline)
      .fontWeight(conversationDetail.conversation.unreadCount > 0 ? .bold : .regular)
      .lineLimit(1)
  ```
- [ ] Consider adding subtle background highlight for unread conversations:
  ```swift
  .listRowBackground(
      conversationDetail.conversation.unreadCount > 0 
          ? Color.blue.opacity(0.05) 
          : Color.clear
  )
  ```

#### 5. Testing & Verification

**Test Scenario 1: Message in Different Conversation**
- [ ] Open conversation A
- [ ] Have another user send message to conversation B
- [ ] Verify in-app banner appears
- [ ] Verify system notification appears
- [ ] Verify conversation B unread count increments
- [ ] Verify conversation A unread count unchanged
- [ ] Tap banner - verify navigation to conversation B
- [ ] Verify conversation B unread count resets to 0

**Test Scenario 2: Message in Current Conversation**
- [ ] Open conversation A
- [ ] Have another user send message to conversation A
- [ ] Verify in-app banner appears (KEY REQUIREMENT)
- [ ] Verify system notification suppressed (existing behavior)
- [ ] Verify unread count does NOT increment
- [ ] Verify message appears in message list

**Test Scenario 3: Message While on Conversation List**
- [ ] Stay on conversation list view
- [ ] Have another user send message to conversation A
- [ ] Verify in-app banner appears
- [ ] Verify system notification appears
- [ ] Verify conversation A unread count increments
- [ ] Verify conversation A moves to top of list
- [ ] Tap conversation A
- [ ] Verify unread count resets

**Test Scenario 4: Group Messages**
- [ ] Join/create group conversation
- [ ] Have another user send group message
- [ ] Verify banner shows "Group: [name]"
- [ ] Verify unread count increments correctly
- [ ] Open group chat
- [ ] Verify unread count resets

**Test Scenario 5: Multiple Rapid Messages**
- [ ] Have user send 3 messages quickly to same conversation
- [ ] Verify banners queue properly (newest replaces current)
- [ ] Verify unread count increments by 3
- [ ] Open conversation
- [ ] Verify count resets to 0

**Test Scenario 6: Offline/Online**
- [ ] Disable network
- [ ] Have messages sent
- [ ] Re-enable network
- [ ] Verify messages sync
- [ ] Verify no duplicate notifications for synced messages
- [ ] Verify unread counts accurate

**Test Scenario 7: App Background/Foreground**
- [ ] Have message arrive while app in background
- [ ] Return to app
- [ ] Verify unread count correct
- [ ] Verify no duplicate in-app banner

#### 6. Code Review Checklist
- [ ] All debug print statements present for troubleshooting
- [ ] MainActor annotations correct
- [ ] No force unwraps or force casts
- [ ] Error handling for localStorage operations
- [ ] Consistent naming conventions
- [ ] Comments explain key logic decisions

#### 7. Documentation
- [ ] Update comments in modified ViewModels
- [ ] Add inline comments for unread count conditions
- [ ] Document notification flow in code comments

**Deliverables**:
- 2-3 files modified (ChatViewModel, ConversationListViewModel, optionally ConversationRowView)
- Full message notification flow working
- Accurate unread counts
- Comprehensive testing completed

---

## Post-Merge Validation
After both PRs merged to main:

### End-to-End Testing
- [ ] Fresh app install - test all scenarios
- [ ] Multiple conversations - verify counts independent
- [ ] Background/foreground transitions
- [ ] Network on/off scenarios
- [ ] Group and one-on-one conversations
- [ ] Rapid message bursts
- [ ] Long message text truncation
- [ ] Navigation from banner works correctly

### Performance Validation
- [ ] No memory leaks (Instruments check)
- [ ] Smooth animations
- [ ] No UI lag when messages arrive
- [ ] Banner dismissal responsive

### Bug Bash
- [ ] Test on different device sizes (iPhone SE, iPhone Pro Max, iPad)
- [ ] Test in light and dark mode
- [ ] Test with accessibility features (larger text, VoiceOver)
- [ ] Edge cases: empty sender names, empty messages

---

## Success Criteria
- ✅ In-app banner appears for ALL incoming messages (including active conversation)
- ✅ System notifications still work as before (suppressed in active conversation)
- ✅ Unread counts increment only when user NOT viewing that conversation
- ✅ Unread counts reset when user opens conversation
- ✅ Banner auto-dismisses after 3 seconds
- ✅ Banner tap navigates correctly
- ✅ Banner swipe dismisses correctly
- ✅ No duplicate notifications from message sync
- ✅ Works for both one-on-one and group conversations
- ✅ Accurate counts persist across app restarts

---

## Future Enhancements (Not in Scope)
- Notification history/center
- Sound/haptic feedback for in-app banners
- Notification action buttons
- Rich media in notifications
- External push notifications (APNs)
- Notification preferences/settings

---

## Notes
- **Testing Strategy**: PR-1 can be tested independently with manual test button
- **Rollback Plan**: Each PR can be reverted independently if issues found
- **Web Dev Analogy**: PR-1 = create components, PR-2 = wire up event handlers

