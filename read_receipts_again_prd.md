# Read Receipts PRD

## Overview
Implement read receipts that display delivery and read status for messages in both one-on-one and group conversations. The read receipt appears under the last message sent by the current user, similar to iMessage.

## Feature Requirements

### One-on-One Conversations

**Display Rules (under last message from current user):**
1. **Not delivered**: Show nothing
2. **Delivered but not read**: Show "Delivered"
3. **Read**: Show "Read at [time]" (e.g., "Read at 5:42pm")

### Group Conversations

**Display Rules (under last message from current user):**
1. **Not delivered to all**: Show nothing
2. **Delivered to all but no reads**: Show "Delivered"
3. **Read by some users**: Show "Read by some users"
4. **Read by all users**: Show "Read by all users"

### Visual Design
- Small, gray text beneath the message bubble
- Only visible for the most recent message from current user
- Right-aligned (under the message bubble)
- Font: caption2, secondary color
- Should not interfere with message spacing

## Technical Architecture

### Data Model

**MessageEntity** includes:
```swift
var deliveredTo: [String] = [] // User IDs who received the message
var deliveredAt: Date? = nil   // When message was first delivered
var readBy: [String] = []       // User IDs who have read the message
var readAt: Date? = nil         // When message was first read (for 1-on-1)
```

**Firestore schema** includes:
- `deliveredTo`: Array of user IDs
- `deliveredAt`: Timestamp
- `readBy`: Array of user IDs
- `readAt`: Timestamp

### Service Layer

**ReadReceiptService**
- `markMessagesAsRead(conversationId:userId:)` - Mark messages as read when user opens chat
- `markAsDelivered(messageId:userId:)` - Mark single message as delivered
- `markMessagesAsDelivered(conversationId:userId:)` - Mark all messages as delivered
- `computeReadReceiptStatus(message:participants:)` - Compute display status
- `readReceiptText(message:participants:currentUserId:)` - Generate display text

**ReadReceiptStatus enum**
- `notDelivered` - Message not yet delivered to recipient(s)
- `delivered` - Delivered but not read
- `readBySome` - Read by some participants (group only)
- `readByAll` - Read by all participants

### UI Components

**ReadReceiptView**
- Displays read receipt text under last message from current user
- Uses `@State` to track receipt text
- Uses `.task(id:)` modifier to reactively update when `deliveredTo` or `readBy` arrays change
- Recomputes display text when message read receipt data changes

**MessageListView**
- Identifies the last message from current user
- Passes `isLastFromCurrentUser` flag to ReadReceiptView
- Only the last message shows a read receipt

### Message Flow

**When User A sends a message to User B:**
1. Message created with empty `deliveredTo` and `readBy` arrays
2. Sent to Firestore with status "delivered"
3. User A sees nothing (not delivered yet)

**When User B receives the message:**
1. FirestoreListenerService detects new message
2. Automatically calls `markAsDelivered(messageId:userId:)` for User B
3. Firestore updated: `deliveredTo` includes User B's ID
4. User A sees "Delivered" appear under their message

**When User B opens the chat:**
1. ChatView.onAppear() calls `markMessagesAsRead()`
2. Firestore updated: `readBy` includes User B's ID, `readAt` timestamp set
3. User A sees "Read at [time]" appear under their message

**Real-time updates:**
- FirestoreListenerService watches for changes to read receipt fields
- When `readBy` or `deliveredTo` changes in Firestore, local MessageEntity updates
- ReadReceiptView's `.task(id:)` modifier triggers recomputation
- UI updates to show new status

### Group Chat Behavior

**When User A sends a message to group with Users B, C, D:**
1. Initially shows nothing (not delivered to all yet)
2. As each user receives, their ID added to `deliveredTo`
3. When all have received → shows "Delivered"
4. As users read, their IDs added to `readBy`
5. When at least one reads → shows "Read by some users"
6. When all read → shows "Read by all users"

## Implementation Details

### Key Files Modified

1. **ReadReceiptView.swift** - UI component with reactive updates
2. **ReadReceiptService.swift** - Business logic for read receipts
3. **ChatViewModel.swift** - Marks messages as read, forces UI refresh
4. **ChatView.swift** - Marks messages as delivered on appear
5. **FirestoreListenerService.swift** - Auto-marks delivered, watches changes
6. **LocalStorageService.swift** - Updates message read receipt fields
7. **MessageListView.swift** - Identifies last message from current user
8. **MessageEntity.swift** - SwiftData model with read receipt fields

### Critical Implementation Notes

**UI Reactivity:**
- ReadReceiptView uses `@State private var receiptText` instead of `@Bindable`
- Uses `.task(id: receiptDataId)` to trigger updates when arrays change
- `receiptDataId` is computed from `deliveredTo`, `readBy`, `deliveredAt`, `readAt`
- This ensures SwiftUI properly detects changes to array properties

**Automatic Delivery Marking:**
- When FirestoreListenerService receives a message, it automatically calls `markAsDelivered`
- This happens for messages from other users (not current user's own messages)
- Ensures delivery tracking works without manual intervention

**Firestore Updates:**
- Uses `FieldValue.arrayUnion()` to add user IDs to arrays
- Prevents duplicate entries
- Batch updates for efficiency when marking multiple messages

**Local Storage Sync:**
- After Firestore updates, local MessageEntity is updated
- SwiftData context saves changes
- UI refresh triggered via `objectWillChange.send()`

## Edge Cases

1. **Offline messages**: Show nothing until delivered
2. **Failed messages**: Don't show read receipt (already has failure indicator)
3. **Pending messages**: Don't show read receipt
4. **Self-messages**: Don't show read receipts
5. **Image messages**: Same rules apply
6. **Group chat - user leaves**: Still count their read/delivery status
7. **Message edited/deleted**: Preserve read receipt state

## Success Criteria

1. ✅ Read receipts appear under last message sent by current user
2. ✅ "Delivered" shows when message reaches recipient but not read
3. ✅ "Read at [time]" shows when recipient reads (1-on-1)
4. ✅ Group chats show "Delivered", "Read by some users", "Read by all users"
5. ✅ Real-time updates work correctly
6. ✅ Works offline (cached state)
7. ✅ No performance degradation

## Testing Guide

### One-on-One Chat Test
1. User A sends message to User B
2. Verify: User A sees nothing initially
3. User B's app receives message (background)
4. Verify: User A sees "Delivered"
5. User B opens chat
6. Verify: User A sees "Read at [time]"

### Group Chat Test
1. User A sends message to group (Users B, C, D)
2. Verify: User A sees nothing initially
3. All users receive message (background)
4. Verify: User A sees "Delivered"
5. User B opens chat (reads message)
6. Verify: User A sees "Read by some users"
7. Users C and D open chat
8. Verify: User A sees "Read by all users"

## Troubleshooting

### If read receipts not showing:
1. Check console logs for `[ReadReceiptService]` - verify `readReceiptText()` is called
2. Check `deliveredTo` and `readBy` arrays - verify they contain correct user IDs
3. Check `isLastFromCurrentUser` flag - verify correct message identified
4. Check `.task(id:)` modifier - verify `receiptDataId` changes when arrays update

### If not updating in real-time:
1. Check Firestore listener - verify `.modified` changes detected
2. Check `syncMessageFromFirestore` - verify local MessageEntity updates
3. Check `objectWillChange.send()` - verify UI refresh triggered
4. Check SwiftData context save - verify changes persisted

## Future Enhancements

1. Tap read receipt to see detailed list of who read/delivered in groups
2. Settings to enable/disable read receipts
3. "Typing..." indicator integration
4. Delivery receipt push notifications

