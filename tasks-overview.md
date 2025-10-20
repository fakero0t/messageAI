# Messaging MVP - Tasks Overview

## Implementation Strategy

This document provides a high-level overview of all Pull Requests (PRs) needed to implement the Messaging MVP. Each PR is designed to be independently completable, tested, and merged.

**Total PRs: 20**

---

## PR Sequence

### Foundation Phase (PRs 1-5)

**PR-1: Project Setup & Firebase Configuration**
- Configure Firebase project
- Add Firebase SDK to Xcode
- Set up GoogleService-Info.plist
- Basic app structure

**PR-2: Authentication System**
- Firebase Auth integration
- Email/password login/signup
- User session management
- Auth state persistence

**PR-3: Basic SwiftUI Structure & Navigation**
- App navigation architecture
- Conversation list view
- Chat view
- Tab/navigation structure

**PR-4: SwiftData Models & Local Persistence**
- Message model
- Conversation model
- User model
- SwiftData container setup

**PR-5: User Profile & Online Status**
- User profile management
- Online/offline status tracking
- Firestore presence system
- User discovery (manual ID entry)

---

### Core Messaging Phase (PRs 6-9)

**PR-6: One-on-One Chat UI**
- Message bubble design
- Message list display
- Input field and send button
- Keyboard handling

**PR-7: Message Sending (Basic - Online Only)**
- Send message to Firestore
- Save to local SwiftData
- Basic message creation
- Message ID generation

**PR-8: Real-Time Message Receiving**
- Firestore real-time listeners
- Update local SwiftData from Firestore
- Message synchronization
- Handle new messages

**PR-9: Optimistic UI & Message Status**
- Optimistic message insertion
- Message status (Sent, Delivered, Read)
- Status indicators in UI
- Status updates from Firestore

---

### Reliability Phase (PRs 10-12)

**PR-10: Offline Message Queueing**
- Detect offline state
- Queue messages locally
- Persist queue in SwiftData
- Auto-send when online

**PR-11: Network Monitoring & Resilience**
- Network reachability monitoring
- Retry logic with exponential backoff
- Connection status UI
- Handle poor network conditions

**PR-12: Crash Recovery & Message Retry**
- Detect unsent messages on app launch
- Retry failed messages
- Failed message UI (delete option)
- Message deduplication

---

### Advanced Features Phase (PRs 13-15)

**PR-13: Read Receipts**
- Track message read status
- Update Firestore with read receipts
- Display read indicators
- Real-time read status updates

**PR-14: Timestamps & Formatting**
- Relative timestamps (Just now, 5m ago)
- Absolute timestamps (Yesterday 3:45 PM)
- Server timestamp handling
- Timestamp display in UI

**PR-15: Conversation List with Unread Badges**
- Conversation list view
- Last message preview
- Unread message count
- Badge display
- Sort by recent activity

---

### Group Chat Phase (PRs 16-17)

**PR-16: Group Chat - Data Models & Creation**
- Group conversation model
- Create group functionality
- Add/remove participants (creator only)
- Group metadata

**PR-17: Group Chat - Messaging & UI**
- Send/receive in group chats
- Group message display
- Participant list view
- Group-specific read receipts

---

### Polish Phase (PRs 18-20)

**PR-18: Foreground Push Notifications**
- Firebase Cloud Messaging setup
- APNs configuration
- Foreground notification handling
- Notification permissions

**PR-19: Testing & Bug Fixes**
- Execute all 10 test scenarios
- Fix identified bugs
- Edge case handling
- Performance optimization

**PR-20: TestFlight Deployment**
- Archive build configuration
- TestFlight upload
- Beta testing setup
- Documentation for testers

---

## Dependencies Map

```
PR-1 (Setup)
  └─> PR-2 (Auth)
       ├─> PR-3 (Navigation)
       │    └─> PR-6 (Chat UI)
       │         └─> PR-7 (Send Messages)
       │              └─> PR-8 (Receive Messages)
       │                   └─> PR-9 (Optimistic UI)
       │                        ├─> PR-10 (Offline Queue)
       │                        │    └─> PR-11 (Network Monitor)
       │                        │         └─> PR-12 (Crash Recovery)
       │                        ├─> PR-13 (Read Receipts)
       │                        └─> PR-14 (Timestamps)
       ├─> PR-4 (SwiftData)
       │    └─> [Used by PR-7, PR-8, PR-10]
       └─> PR-5 (User Profile)
            └─> [Used by PR-6, PR-8]

PR-15 (Conversation List) <- Depends on PR-8, PR-14
PR-16 (Group Models) <- Depends on PR-4, PR-8
PR-17 (Group UI) <- Depends on PR-16, PR-9
PR-18 (Notifications) <- Depends on PR-8
PR-19 (Testing) <- Depends on ALL previous PRs
PR-20 (Deployment) <- Depends on PR-19
```

---

## Detailed Task Files

Each PR has a corresponding detailed task file:

- `tasks-v1.md` - PR-1: Project Setup & Firebase Configuration
- `tasks-v2.md` - PR-2: Authentication System
- `tasks-v3.md` - PR-3: Basic SwiftUI Structure & Navigation
- `tasks-v4.md` - PR-4: SwiftData Models & Local Persistence
- `tasks-v5.md` - PR-5: User Profile & Online Status
- `tasks-v6.md` - PR-6: One-on-One Chat UI
- `tasks-v7.md` - PR-7: Message Sending (Basic - Online Only)
- `tasks-v8.md` - PR-8: Real-Time Message Receiving
- `tasks-v9.md` - PR-9: Optimistic UI & Message Status
- `tasks-v10.md` - PR-10: Offline Message Queueing
- `tasks-v11.md` - PR-11: Network Monitoring & Resilience
- `tasks-v12.md` - PR-12: Crash Recovery & Message Retry
- `tasks-v13.md` - PR-13: Read Receipts
- `tasks-v14.md` - PR-14: Timestamps & Formatting
- `tasks-v15.md` - PR-15: Conversation List with Unread Badges
- `tasks-v16.md` - PR-16: Group Chat - Data Models & Creation
- `tasks-v17.md` - PR-17: Group Chat - Messaging & UI
- `tasks-v18.md` - PR-18: Foreground Push Notifications
- `tasks-v19.md` - PR-19: Testing & Bug Fixes
- `tasks-v20.md` - PR-20: TestFlight Deployment

---

## Testing Checkpoints

After completing specific PRs, test these scenarios:

**After PR-8**: Test Scenario #1 (Two-device real-time chat)
**After PR-10**: Test Scenario #2 (Offline → Online transition)
**After PR-12**: Test Scenarios #4, #5 (Force-quit, poor network)
**After PR-13**: Test Scenario #8 (Read receipts)
**After PR-14**: Verify timestamp display
**After PR-17**: Test Scenario #7 (Group chat)
**Before PR-19**: Execute ALL 10 test scenarios

---

## Estimated Timeline

- **Foundation Phase (PR 1-5)**: 1.5 weeks
- **Core Messaging Phase (PR 6-9)**: 1.5 weeks
- **Reliability Phase (PR 10-12)**: 2 weeks
- **Advanced Features Phase (PR 13-15)**: 1.5 weeks
- **Group Chat Phase (PR 16-17)**: 1.5 weeks
- **Polish Phase (PR 18-20)**: 1 week

**Total: ~9 weeks**

---

*Last Updated: October 20, 2025*

