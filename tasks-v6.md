# PR-6: One-on-One Chat UI

## Overview
Create the complete chat interface with message bubbles, scrolling, keyboard handling, and input field. Focus on UI/UX without actual message sending logic yet.

## Dependencies
- PR-3: Basic SwiftUI Structure & Navigation
- PR-5: User Profile & Online Status

## Tasks

### 1. Create Message Bubble Components
- [ ] Create `Views/Chat/MessageBubbleView.swift`
  - [ ] Different styles for sent vs received messages
  - [ ] Sent messages: blue bubble, right-aligned
  - [ ] Received messages: gray bubble, left-aligned
  - [ ] Display message text
  - [ ] Display timestamp
  - [ ] Display message status icon (for sent messages)
  - [ ] Proper padding and sizing

### 2. Create Message List View
- [ ] Create `Views/Chat/MessageListView.swift`
  - [ ] ScrollView with messages
  - [ ] Reversed list (newest at bottom)
  - [ ] Auto-scroll to bottom on new message
  - [ ] Maintain scroll position when keyboard appears
  - [ ] Pull-to-refresh for loading history (placeholder)
  - [ ] Handle empty state

### 3. Create Message Input View
- [ ] Create `Views/Chat/MessageInputView.swift`
  - [ ] TextField for message composition
  - [ ] Send button (with SF Symbol)
  - [ ] Disable send button when text empty
  - [ ] Multi-line text support
  - [ ] Character limit display (optional)
  - [ ] Proper styling and padding

### 4. Update Chat View
- [ ] Enhance `Views/Chat/ChatView.swift`
  - [ ] Integrate MessageListView
  - [ ] Integrate MessageInputView
  - [ ] Proper layout with VStack
  - [ ] Show recipient online status in nav bar
  - [ ] Handle keyboard appearance/dismissal
  - [ ] Focus management
  - [ ] Dismiss keyboard on scroll

### 5. Create Mock Data for Testing
- [ ] Create `ViewModels/ChatViewModel.swift`
  - [ ] ObservableObject for chat state
  - [ ] @Published messages array (mock data for now)
  - [ ] Method to add message (local only for testing)
  - [ ] Recipient user info
  - [ ] Conversation ID

### 6. Handle Keyboard Interactions
- [ ] Implement keyboard avoidance
  - [ ] Use .keyboardShortcut() or similar
  - [ ] ScrollView adjustment when keyboard appears
  - [ ] Input field stays above keyboard
  - [ ] Dismiss keyboard on tap outside
  - [ ] Return key to send (optional)

### 7. Add Animations and Polish
- [ ] Smooth scrolling animations
- [ ] Message appear animations
- [ ] Keyboard transition animations
- [ ] Haptic feedback on send (optional)

## Files to Create/Modify

### New Files
- `swift_demo/Views/Chat/MessageBubbleView.swift`
- `swift_demo/Views/Chat/MessageListView.swift`
- `swift_demo/Views/Chat/MessageInputView.swift`
- `swift_demo/ViewModels/ChatViewModel.swift`

### Modified Files
- `swift_demo/Views/Chat/ChatView.swift` - Complete implementation

## Code Structure Examples

### MessageBubbleView.swift
```swift
import SwiftUI

struct MessageBubbleView: View {
    let message: MessageEntity
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(12)
                    .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(16)
                
                HStack(spacing: 4) {
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if isFromCurrentUser {
                        Image(systemName: message.status.iconName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !isFromCurrentUser {
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
}
```

### MessageListView.swift
```swift
import SwiftUI

struct MessageListView: View {
    let messages: [MessageEntity]
    let currentUserId: String
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { message in
                        MessageBubbleView(
                            message: message,
                            isFromCurrentUser: message.senderId == currentUserId
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
}
```

### MessageInputView.swift
```swift
import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .lineLimit(1...5)
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(text.isEmpty ? .gray : .blue)
            }
            .disabled(text.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}
```

### ChatView.swift (Updated)
```swift
import SwiftUI

struct ChatView: View {
    let recipientId: String
    let recipientName: String
    
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    
    init(recipientId: String, recipientName: String) {
        self.recipientId = recipientId
        self.recipientName = recipientName
        _viewModel = StateObject(wrappedValue: ChatViewModel(recipientId: recipientId))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            MessageListView(
                messages: viewModel.messages,
                currentUserId: viewModel.currentUserId
            )
            
            MessageInputView(text: $messageText) {
                sendMessage()
            }
        }
        .navigationTitle(recipientName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(recipientName)
                        .font(.headline)
                    
                    OnlineStatusView(
                        isOnline: viewModel.recipientOnline,
                        lastSeen: viewModel.recipientLastSeen
                    )
                }
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
    }
    
    func sendMessage() {
        guard !messageText.isEmpty else { return }
        viewModel.sendMessage(text: messageText)
        messageText = ""
    }
}
```

### ChatViewModel.swift
```swift
import Foundation
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [MessageEntity] = []
    @Published var recipientOnline = false
    @Published var recipientLastSeen: Date?
    
    let recipientId: String
    let currentUserId: String
    let conversationId: String
    
    init(recipientId: String) {
        self.recipientId = recipientId
        self.currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
        self.conversationId = Self.generateConversationId(userId1: currentUserId, userId2: recipientId)
        
        loadMockMessages() // Temporary
    }
    
    func sendMessage(text: String) {
        // Placeholder - will implement in PR-7
        let message = MessageEntity(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: currentUserId,
            text: text,
            timestamp: Date(),
            status: .pending
        )
        messages.append(message)
    }
    
    private func loadMockMessages() {
        // Mock data for UI testing
    }
    
    static func generateConversationId(userId1: String, userId2: String) -> String {
        let sorted = [userId1, userId2].sorted()
        return sorted.joined(separator: "_")
    }
}
```

## Acceptance Criteria
- [ ] Message bubbles display correctly
- [ ] Sent messages appear on right in blue
- [ ] Received messages appear on left in gray
- [ ] Messages scroll smoothly
- [ ] Auto-scroll to bottom when new message arrives
- [ ] Input field stays above keyboard
- [ ] Send button disabled when text empty
- [ ] Keyboard dismisses on scroll or tap outside
- [ ] Timestamps display on each message
- [ ] Message status icons show for sent messages
- [ ] Multi-line text input works
- [ ] Recipient online status shows in navigation bar
- [ ] UI responsive and smooth

## Testing
1. Navigate to chat view
2. Type message in input field
3. Verify send button enables
4. Tap send
5. Verify message appears in chat as blue bubble on right
6. Verify timestamp shows
7. Test multi-line message (press return)
8. Verify scrolling works
9. Verify keyboard shows/hides properly
10. Test with multiple messages
11. Verify auto-scroll to newest message
12. Test recipient online status display

## Notes
- Focus on UI polish - this is user-facing
- Messages are mock data for now - real sending in PR-7
- Follow iOS Messages app design patterns
- Use SF Symbols for icons
- Ensure keyboard handling is smooth
- Test on different screen sizes
- Consider dark mode support

## Next PR
PR-7: Message Sending (Basic - Online Only) (depends on this PR)

