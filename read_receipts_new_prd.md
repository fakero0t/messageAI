# Read Receipts PRD - iMessage Style

## Overview
Implement read receipts that appear under the last message sent by the current user, matching Apple iMessage behavior. Show delivery and read status for both one-on-one and group conversations.

## Current State

### Existing Infrastructure
- `MessageEntity.readBy: [String]` - Array tracking user IDs who have read the message
- `MessageStatus` enum - pending, sent, queued, delivered, read, failed
- `ReadReceiptService` - Handles marking messages as read
- `FirestoreListenerService` - Real-time message updates

### Gaps
- No separate delivery tracking (delivered vs read)
- No UI component to display read receipts under messages
- No group-specific read receipt aggregation logic
- Status updates don't distinguish between delivered and read for display purposes

## Requirements

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

## Technical Implementation

### 1. Data Model Updates

**MessageEntity additions:**
```swift
var deliveredTo: [String] = [] // User IDs who received the message
var deliveredAt: Date? // When message was first delivered
var readAt: Date? // When message was first read (for 1-on-1)
```

**Firestore schema updates:**
- Add `deliveredTo` array field to messages
- Add `deliveredAt` timestamp field
- Add `readAt` timestamp field

### 2. New UI Component

**File: `ReadReceiptView.swift`**
- Input: message, conversation participants, current user ID
- Computes display text based on message state
- Returns Text view with appropriate styling
- Only renders for last message from current user

**Logic:**
```swift
func readReceiptText(
    message: MessageEntity, 
    isLastFromCurrentUser: Bool,
    participants: [String],
    currentUserId: String
) -> String? {
    guard isLastFromCurrentUser else { return nil }
    guard message.senderId == currentUserId else { return nil }
    
    let isGroupChat = participants.count > 2
    
    if isGroupChat {
        return groupReadReceiptText(message, participants)
    } else {
        return oneOnOneReadReceiptText(message, currentUserId)
    }
}
```

### 3. Service Enhancements

**ReadReceiptService updates:**

**New method: markAsDelivered**
```swift
func markAsDelivered(messageId: String, userId: String) async throws {
    // Update Firestore: add to deliveredTo array
    // Update local storage
    // Set deliveredAt timestamp if first delivery
}
```

**Enhanced: markMessagesAsRead**
- Also set `readAt` timestamp for first read
- Update message status appropriately

**New method: computeReadReceiptStatus**
```swift
func computeReadReceiptStatus(
    message: MessageEntity,
    participants: [String]
) -> ReadReceiptStatus {
    // Returns: notDelivered, delivered, readBySome, readByAll
}
```

### 4. Message Delivery Flow

**When receiving a message:**
1. FirestoreListenerService detects new message
2. LocalStorageService saves message
3. ReadReceiptService.markAsDelivered() called automatically
4. Sender sees "Delivered" appear under their message

**When opening a conversation:**
1. ChatView.onAppear() calls ReadReceiptService.markMessagesAsRead()
2. Also calls ReadReceiptService.markAsDelivered() for any undelivered messages
3. Sender sees "Read at [time]" appear

### 5. MessageListView Integration

**Changes to MessageListView:**
- Identify last message from current user
- Pass flag `isLastFromCurrentUser` to MessageBubbleView
- Add ReadReceiptView below that message

**Changes to MessageBubbleView:**
- Accept `isLastFromCurrentUser: Bool` parameter
- Accept `participants: [String]` parameter
- Render ReadReceiptView conditionally

### 6. Real-time Updates

**Listener updates:**
- FirestoreListenerService watches for changes to `readBy` and `deliveredTo` arrays
- Updates trigger UI refresh
- Read receipt text updates automatically

## Implementation Steps

### Phase 1: Data Layer (Backend)
1. Add new fields to MessageEntity SwiftData model
2. Update Firestore message schema
3. Create migration if needed for existing messages
4. Update MessageService to set deliveredTo on send

### Phase 2: Service Layer
1. Enhance ReadReceiptService with delivery tracking
2. Add computeReadReceiptStatus() logic
3. Update markMessagesAsRead() to set readAt timestamp
4. Add markAsDelivered() method
5. Update FirestoreListenerService to watch new fields

### Phase 3: UI Layer
1. Create ReadReceiptView component
2. Add logic to identify last message from current user in MessageListView
3. Integrate ReadReceiptView into MessageBubbleView
4. Style and position correctly
5. Test with various states

### Phase 4: Integration & Testing
1. Test one-on-one conversations
2. Test group conversations with partial reads
3. Test real-time updates when recipient reads
4. Test delivery tracking
5. Test edge cases (offline, failed messages, etc.)

## Edge Cases

1. **Offline messages**: Show nothing until delivered
2. **Failed messages**: Don't show read receipt (already has failure indicator)
3. **Pending messages**: Don't show read receipt
4. **Self-messages**: Don't show read receipts
5. **Image messages**: Same rules apply
6. **Group chat - user leaves**: Still count their read/delivery status
7. **Message edited/deleted**: Preserve read receipt state

## Files to Modify

### Models
- `swift_demo/Models/SwiftData/MessageEntity.swift` - Add deliveredTo, deliveredAt, readAt fields

### Services  
- `swift_demo/Services/ReadReceiptService.swift` - Add delivery tracking, status computation
- `swift_demo/Services/MessageService.swift` - Set deliveredTo on send
- `swift_demo/Services/FirestoreListenerService.swift` - Watch new fields

### Views
- `swift_demo/Views/Components/ReadReceiptView.swift` - NEW: Read receipt display component
- `swift_demo/Views/Chat/MessageBubbleView.swift` - Integrate ReadReceiptView
- `swift_demo/Views/Chat/MessageListView.swift` - Identify last message, pass data

### Utilities
- `swift_demo/Utilities/DateFormatting.swift` - May need additional time format helpers

## Success Criteria

1. Read receipts appear under last message sent by current user
2. "Delivered" shows when message reaches recipient but not read
3. "Read at [time]" shows when recipient reads (1-on-1)
4. Group chats show "Delivered", "Read by some users", "Read by all users"
5. Real-time updates work correctly
6. No performance degradation
7. Works offline (cached state)
8. Matches iMessage visual style

## Future Enhancements

1. Tap read receipt to see detailed list of who read/delivered in groups
2. Settings to enable/disable read receipts
3. "Typing..." indicator integration
4. Delivery receipt push notifications

