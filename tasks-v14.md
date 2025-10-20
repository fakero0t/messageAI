# PR-14: Timestamps & Formatting

## Overview
Implement proper timestamp display for messages with relative time for recent messages and absolute time for older messages. Handle server timestamps correctly.

## Dependencies
- PR-8: Real-Time Message Receiving

## Tasks

### 1. Create Date Formatting Utilities
- [ ] Create `Utilities/DateFormatting.swift`
  - [ ] Relative time formatter (Just now, 5m ago, 2h ago)
  - [ ] Absolute time formatter (Yesterday 3:45 PM, Dec 15, 2024)
  - [ ] Smart formatting based on message age
  - [ ] Localized formatting

### 2. Implement Relative Time Display
- [ ] Messages from today: "Just now", "5 minutes ago", "2 hours ago"
- [ ] Messages from yesterday: "Yesterday at 3:45 PM"
- [ ] Messages from this week: "Monday at 3:45 PM"
- [ ] Older messages: "Dec 15, 2024 at 3:45 PM"

### 3. Add Date Separators
- [ ] Create `Views/Chat/DateSeparatorView.swift`
  - [ ] Show date between messages from different days
  - [ ] "Today", "Yesterday", "Monday", or full date
  - [ ] Subtle styling

### 4. Update Message List View
- [ ] Modify `MessageListView.swift`
  - [ ] Insert date separators between messages
  - [ ] Group messages by date
  - [ ] Smart separator logic

### 5. Handle Server Timestamps
- [ ] Ensure Firestore server timestamps used
  - [ ] Prevent clock skew issues
  - [ ] Convert server timestamp to local Date
  - [ ] Handle timestamp nil (pending messages)

### 6. Update Message Bubble Timestamps
- [ ] Enhance `MessageBubbleView.swift`
  - [ ] Show formatted time below message
  - [ ] Use relative time for recent messages
  - [ ] Use absolute time for older messages
  - [ ] Update timestamps dynamically (optional)

### 7. Format Conversation List Timestamps
- [ ] Update `ConversationListView.swift`
  - [ ] Show last message time
  - [ ] "Just now", "5m", "2h", "Yesterday", or date
  - [ ] Keep formatting consistent

### 8. Handle Edge Cases
- [ ] Messages with no timestamp
- [ ] Future timestamps (clock skew)
- [ ] Very old messages
- [ ] Timezone handling

## Files to Create/Modify

### New Files
- `swift_demo/Utilities/DateFormatting.swift`
- `swift_demo/Views/Chat/DateSeparatorView.swift`

### Modified Files
- `swift_demo/Views/Chat/MessageBubbleView.swift` - Formatted timestamps
- `swift_demo/Views/Chat/MessageListView.swift` - Date separators
- `swift_demo/Views/Conversations/ConversationListView.swift` - Last message time

## Code Structure Examples

### DateFormatting.swift
```swift
import Foundation

extension Date {
    /// Returns a user-friendly relative or absolute time string
    func chatTimestamp() -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: self, to: now)
        
        // Just now (< 1 minute)
        if let minutes = components.minute, minutes < 1 {
            return "Just now"
        }
        
        // Minutes ago (< 1 hour)
        if let minutes = components.minute, minutes < 60 {
            return "\(minutes)m ago"
        }
        
        // Hours ago (< 24 hours, same day)
        if let hours = components.hour, hours < 24, calendar.isDateInToday(self) {
            return "\(hours)h ago"
        }
        
        // Yesterday
        if calendar.isDateInYesterday(self) {
            return "Yesterday at \(self.formatted(date: .omitted, time: .shortened))"
        }
        
        // This week
        if let days = components.day, days < 7 {
            let weekday = self.formatted(.dateTime.weekday(.wide))
            let time = self.formatted(date: .omitted, time: .shortened)
            return "\(weekday) at \(time)"
        }
        
        // Older
        return self.formatted(date: .abbreviated, time: .shortened)
    }
    
    /// Returns short timestamp for conversation list
    func conversationTimestamp() -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: self, to: now)
        
        // Minutes
        if let minutes = components.minute, minutes < 60 {
            return minutes < 1 ? "now" : "\(minutes)m"
        }
        
        // Hours (today)
        if let hours = components.hour, hours < 24, calendar.isDateInToday(self) {
            return "\(hours)h"
        }
        
        // Yesterday
        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }
        
        // This week
        if let days = components.day, days < 7 {
            return self.formatted(.dateTime.weekday(.abbreviated))
        }
        
        // Older
        return self.formatted(date: .numeric, time: .omitted)
    }
    
    /// Returns date separator text
    func dateSeparatorText() -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(self) {
            return "Today"
        }
        
        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }
        
        // This week
        let now = Date()
        let components = calendar.dateComponents([.day], from: self, to: now)
        if let days = components.day, days < 7 {
            return self.formatted(.dateTime.weekday(.wide))
        }
        
        // Older
        return self.formatted(date: .abbreviated, time: .omitted)
    }
    
    /// Check if two dates are on the same day
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}
```

### DateSeparatorView.swift
```swift
import SwiftUI

struct DateSeparatorView: View {
    let date: Date
    
    var body: some View {
        HStack {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4))
            
            Text(date.dateSeparatorText())
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(.systemBackground))
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4))
        }
        .padding(.vertical, 8)
    }
}
```

### MessageListView.swift (Updated with Date Separators)
```swift
import SwiftUI

struct MessageListView: View {
    let messages: [MessageEntity]
    let currentUserId: String
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        // Show date separator if different day from previous message
                        if shouldShowDateSeparator(at: index) {
                            DateSeparatorView(date: message.timestamp)
                        }
                        
                        MessageBubbleView(
                            message: message,
                            isFromCurrentUser: message.senderId == currentUserId,
                            onRetry: { /* retry logic */ },
                            onDelete: { /* delete logic */ }
                        )
                        .id(message.id)
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: messages.count) { oldValue, newValue in
                if let lastMessage = messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private func shouldShowDateSeparator(at index: Int) -> Bool {
        guard index > 0 else { return true } // Always show for first message
        
        let currentMessage = messages[index]
        let previousMessage = messages[index - 1]
        
        return !currentMessage.timestamp.isSameDay(as: previousMessage.timestamp)
    }
}
```

### MessageBubbleView.swift (Updated)
```swift
import SwiftUI

struct MessageBubbleView: View {
    let message: MessageEntity
    let isFromCurrentUser: Bool
    let onRetry: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(12)
                    .background(bubbleColor)
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(16)
                
                HStack(spacing: 4) {
                    Text(message.timestamp.chatTimestamp())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if isFromCurrentUser {
                        statusIndicator
                    }
                }
                
                if message.status == .failed && isFromCurrentUser {
                    FailedMessageActionsView(onRetry: onRetry, onDelete: onDelete)
                }
            }
            
            if !isFromCurrentUser {
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
    
    private var bubbleColor: Color {
        if message.status == .failed {
            return Color.red.opacity(0.7)
        }
        return isFromCurrentUser ? Color.blue : Color(.systemGray5)
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        // ... existing status indicator code ...
    }
}
```

### ConversationListView.swift (Add Timestamp)
```swift
import SwiftUI

struct ConversationListView: View {
    @State private var conversations: [ConversationEntity] = []
    @State private var showNewChat = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(conversations) { conversation in
                    NavigationLink {
                        ChatView(
                            recipientId: getRecipientId(from: conversation),
                            recipientName: getRecipientName(from: conversation)
                        )
                    } label: {
                        ConversationRowView(conversation: conversation)
                    }
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewChatView()
            }
            .onAppear {
                loadConversations()
            }
        }
    }
    
    func loadConversations() {
        // Load conversations from local storage
    }
    
    func getRecipientId(from conversation: ConversationEntity) -> String {
        // Extract recipient ID
        ""
    }
    
    func getRecipientName(from conversation: ConversationEntity) -> String {
        // Fetch recipient name
        ""
    }
}

struct ConversationRowView: View {
    let conversation: ConversationEntity
    
    var body: some View {
        HStack {
            // Avatar placeholder
            Circle()
                .fill(Color.blue)
                .frame(width: 50, height: 50)
                .overlay {
                    Text(conversation.participantIds.first?.prefix(1).uppercased() ?? "?")
                        .foregroundColor(.white)
                        .font(.headline)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Recipient Name") // Will fetch from UserService
                    .font(.headline)
                
                if let lastMessage = conversation.lastMessageText {
                    Text(lastMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let lastMessageTime = conversation.lastMessageTime {
                    Text(lastMessageTime.conversationTimestamp())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(.caption2)
                        .padding(6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 4)
    }
}
```

## Acceptance Criteria
- [ ] Recent messages show relative time ("5m ago")
- [ ] Older messages show absolute time with date
- [ ] Date separators appear between different days
- [ ] "Today", "Yesterday" labels used appropriately
- [ ] Conversation list shows formatted timestamps
- [ ] Server timestamps used from Firestore
- [ ] Formatting is consistent across app
- [ ] Timestamps update appropriately
- [ ] Localized formatting works
- [ ] Edge cases handled (no timestamp, future dates)

## Testing
1. Send message and verify shows "Just now"
2. Wait 5 minutes, verify shows "5m ago"
3. Send messages over multiple days
4. Verify date separators appear
5. Verify "Today", "Yesterday" labels
6. Check conversation list timestamps
7. Test with messages from different weeks
8. Test with very old messages
9. Verify timestamps in different timezones
10. Test with system locale changes

## Notes
- Use RelativeDateTimeFormatter for relative times
- Server timestamps prevent clock skew
- Date separators improve readability
- Keep formatting consistent with iOS Messages
- Consider updating relative times periodically (optional)
- Localization important for global apps
- Format should be clear and unambiguous

## Next PR
PR-15: Conversation List with Unread Badges (depends on PR-8, PR-14)

