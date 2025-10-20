# PR-13: Read Receipts

## Overview
Implement read receipts to track when recipients have read messages. Update sender's UI with read status in real-time.

## Dependencies
- PR-8: Real-Time Message Receiving

## Tasks

### 1. Track Message Read Events
- [ ] Update `ChatViewModel.swift`
  - [ ] Detect when chat view appears
  - [ ] Mark all messages as read when conversation opens
  - [ ] Update Firestore with read status
  - [ ] Add current user to readBy array

### 2. Update Firestore Schema
- [ ] Modify message documents
  - [ ] `readBy` array contains user IDs who have read
  - [ ] Update readBy when user opens conversation
  - [ ] Batch update for multiple unread messages

### 3. Implement Read Status Updates
- [ ] Create `Services/ReadReceiptService.swift`
  - [ ] Method to mark messages as read
  - [ ] Method to mark conversation as read
  - [ ] Batch operations for efficiency
  - [ ] Update local and Firestore

### 4. Update Message Status Display
- [ ] Update `MessageBubbleView.swift`
  - [ ] Show read status for sent messages
  - [ ] Blue checkmarks for read
  - [ ] Gray checkmarks for delivered but not read
  - [ ] Distinguish between delivered and read

### 5. Listen to Read Receipt Updates
- [ ] Existing Firestore listener will handle this
  - [ ] When readBy array updates, sync to local
  - [ ] Update message status to .read
  - [ ] Update UI automatically

### 6. Handle Unread Counts
- [ ] Update `ConversationEntity`
  - [ ] Track unread message count per conversation
  - [ ] Update count when messages arrive
  - [ ] Reset count when conversation opened
  - [ ] Display badge in conversation list

### 7. Mark Read on View Appearance
- [ ] Update `ChatView.swift`
  - [ ] Call markAsRead when view appears
  - [ ] Call markAsRead when app returns to foreground
  - [ ] Handle only unread messages

### 8. Optimize Batch Operations
- [ ] Don't update every message individually
  - [ ] Batch multiple message updates
  - [ ] Use Firestore batch writes
  - [ ] Limit to 500 operations per batch

## Files to Create/Modify

### New Files
- `swift_demo/Services/ReadReceiptService.swift`

### Modified Files
- `swift_demo/ViewModels/ChatViewModel.swift` - Mark as read
- `swift_demo/Views/Chat/ChatView.swift` - Trigger read updates
- `swift_demo/Views/Chat/MessageBubbleView.swift` - Read indicators
- `swift_demo/Models/SwiftData/ConversationEntity.swift` - Unread count

## Code Structure Examples

### ReadReceiptService.swift
```swift
import Foundation
import FirebaseFirestore

class ReadReceiptService {
    static let shared = ReadReceiptService()
    private let db = Firestore.firestore()
    private let localStorage = LocalStorageService.shared
    
    func markMessagesAsRead(
        conversationId: String,
        userId: String
    ) async throws {
        // Get unread messages in conversation
        let messages = try await MainActor.run {
            try localStorage.fetchMessages(for: conversationId)
        }
        
        let unreadMessages = messages.filter { message in
            message.senderId != userId && !message.readBy.contains(userId)
        }
        
        guard !unreadMessages.isEmpty else { return }
        
        print("📖 Marking \(unreadMessages.count) messages as read")
        
        // Batch update Firestore
        let batch = db.batch()
        
        for message in unreadMessages {
            let messageRef = db.collection("messages").document(message.id)
            batch.updateData([
                "readBy": FieldValue.arrayUnion([userId])
            ], forDocument: messageRef)
        }
        
        try await batch.commit()
        
        // Update local storage
        try await MainActor.run {
            for message in unreadMessages {
                message.readBy.append(userId)
                
                // Update status to read if all participants have read
                if shouldMarkAsRead(message: message, conversationId: conversationId) {
                    try? localStorage.updateMessageStatus(messageId: message.id, status: .read)
                }
            }
            
            // Reset unread count for conversation
            try? localStorage.resetUnreadCount(conversationId: conversationId)
        }
    }
    
    private func shouldMarkAsRead(message: MessageEntity, conversationId: String) -> Bool {
        // For one-on-one: if recipient has read, mark as read
        // For group: could require all to read, or just show count
        let participants = conversationId.split(separator: "_").map(String.init)
        
        if participants.count == 2 {
            // One-on-one: both users should be in readBy
            return message.readBy.count == 2
        } else {
            // Group: mark as read if at least one other person read
            return message.readBy.count > 1
        }
    }
}
```

### ChatViewModel.swift (Updated)
```swift
import Foundation
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [MessageEntity] = []
    @Published var recipientOnline = false
    @Published var recipientLastSeen: Date?
    @Published var errorMessage: String?
    @Published var isSending = false
    @Published var isOffline = false
    
    let recipientId: String
    let currentUserId: String
    let conversationId: String
    
    private let messageService = MessageService.shared
    private let localStorage = LocalStorageService.shared
    private let listenerService = FirestoreListenerService.shared
    private let queueService = MessageQueueService.shared
    private let networkMonitor = NetworkMonitor.shared
    private let readReceiptService = ReadReceiptService.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    init(recipientId: String) {
        self.recipientId = recipientId
        self.currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
        self.conversationId = ConversationService.shared.generateConversationId(
            userId1: currentUserId,
            userId2: recipientId
        )
        
        loadLocalMessages()
        startListening()
        observeNetwork()
        markMessagesAsRead()
    }
    
    deinit {
        listenerService.stopListening(conversationId: conversationId)
    }
    
    func markMessagesAsRead() {
        Task {
            try? await readReceiptService.markMessagesAsRead(
                conversationId: conversationId,
                userId: currentUserId
            )
            loadLocalMessages()
        }
    }
    
    // ... existing methods ...
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
    @Environment(\.scenePhase) private var scenePhase
    
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
        .onAppear {
            viewModel.markMessagesAsRead()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                viewModel.markMessagesAsRead()
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

### MessageBubbleView.swift (Updated for Read Status)
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
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
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
        switch message.status {
        case .pending:
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 12, height: 12)
        case .sent, .queued:
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundColor(.secondary)
        case .delivered:
            HStack(spacing: 1) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        case .read:
            HStack(spacing: 1) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.caption2)
            .foregroundColor(.blue)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.red)
        }
    }
}
```

### ConversationEntity.swift (Updated)
```swift
import Foundation
import SwiftData

@Model
final class ConversationEntity {
    @Attribute(.unique) var id: String
    var participantIds: [String]
    var isGroup: Bool
    var lastMessageText: String?
    var lastMessageTime: Date?
    var unreadCount: Int
    
    @Relationship(deleteRule: .cascade)
    var messages: [MessageEntity]
    
    init(id: String, participantIds: [String], isGroup: Bool = false) {
        self.id = id
        self.participantIds = participantIds
        self.isGroup = isGroup
        self.unreadCount = 0
        self.messages = []
    }
}
```

### LocalStorageService.swift (Add Read Receipt Methods)
```swift
@MainActor
class LocalStorageService {
    // ... existing methods ...
    
    func resetUnreadCount(conversationId: String) throws {
        let predicate = #Predicate<ConversationEntity> { $0.id == conversationId }
        let descriptor = FetchDescriptor<ConversationEntity>(predicate: predicate)
        
        if let conversation = try modelContext.fetch(descriptor).first {
            conversation.unreadCount = 0
            try modelContext.save()
        }
    }
    
    func incrementUnreadCount(conversationId: String) throws {
        let predicate = #Predicate<ConversationEntity> { $0.id == conversationId }
        let descriptor = FetchDescriptor<ConversationEntity>(predicate: predicate)
        
        if let conversation = try modelContext.fetch(descriptor).first {
            conversation.unreadCount += 1
            try modelContext.save()
        }
    }
}
```

## Acceptance Criteria
- [ ] Messages marked as read when conversation opened
- [ ] Read receipts update in Firestore
- [ ] Read status updates in sender's UI
- [ ] Blue checkmarks show for read messages
- [ ] Gray checkmarks show for delivered but unread
- [ ] Unread count tracked per conversation
- [ ] Unread count resets when conversation opened
- [ ] Read receipts work in real-time
- [ ] Batch updates for efficiency
- [ ] Read receipts work in group chats

## Testing
1. Log in as User A on Device 1
2. Log in as User B on Device 2
3. Send message from Device 1 to User B
4. Verify message shows gray double checkmark (delivered)
5. Open conversation on Device 2
6. Verify message marked as read in Firestore
7. Check Device 1 - verify checkmark turns blue (read)
8. Send multiple messages from Device 1
9. Open conversation on Device 2
10. Verify all messages marked as read
11. Verify batch update happened (check Firestore logs)

## Notes
- Read receipts are key messaging feature
- Blue checkmarks standard for "read" (WhatsApp convention)
- Batch operations prevent excessive Firestore writes
- Only mark as read when user actually views conversation
- Consider privacy settings (optional: disable read receipts)
- Group chats: show read count or individual receipts
- Efficient: don't update already-read messages

## Next PR
PR-14: Timestamps & Formatting (depends on PR-8)

