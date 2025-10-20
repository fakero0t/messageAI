# PR-9: Optimistic UI & Message Status

## Overview
Refine message status flow and optimistic UI updates. Ensure messages appear instantly when sent, then update with delivery confirmations.

## Dependencies
- PR-8: Real-Time Message Receiving

## Tasks

### 1. Implement Optimistic Message Insertion
- [ ] Update `ChatViewModel.swift`
  - [ ] Insert message to UI immediately on send
  - [ ] Set initial status to .pending
  - [ ] Don't wait for Firestore confirmation
  - [ ] Update message when Firestore confirms

### 2. Create Status Flow
- [ ] Define clear status progression
  - [ ] .pending: Just created, not yet saved locally
  - [ ] .sent: Saved to local SwiftData
  - [ ] .delivered: Confirmed in Firestore
  - [ ] .read: Recipient has read (PR-13)
  - [ ] .failed: Send failed

### 3. Update Message Status Indicators
- [ ] Enhance `MessageBubbleView.swift`
  - [ ] Different icons for each status
  - [ ] pending: clock icon
  - [ ] sent: single checkmark
  - [ ] delivered: double checkmark
  - [ ] read: blue double checkmark (later)
  - [ ] failed: exclamation mark
  - [ ] Animate status transitions

### 4. Handle Message Updates
- [ ] Track message by ID
- [ ] When Firestore sync returns message, update existing local message
- [ ] Don't duplicate message in UI
- [ ] Smooth status indicator transition

### 5. Implement Retry for Failed Messages
- [ ] Add retry button for failed messages
- [ ] Create `Views/Chat/FailedMessageView.swift`
  - [ ] Show error indicator
  - [ ] Retry button
  - [ ] Delete button
- [ ] Handle retry logic in ChatViewModel

### 6. Add Loading States
- [ ] Show sending indicator when appropriate
- [ ] Disable input while sending (optional)
- [ ] Activity indicator for long operations

### 7. Handle Edge Cases
- [ ] Message sent while offline (will queue in PR-10)
- [ ] Message fails due to network error
- [ ] Duplicate prevention
- [ ] Out-of-order delivery

### 8. Polish Animations
- [ ] Message appear animation
- [ ] Status icon update animation
- [ ] Smooth transitions
- [ ] Haptic feedback (optional)

## Files to Create/Modify

### New Files
- `swift_demo/Views/Chat/FailedMessageView.swift`

### Modified Files
- `swift_demo/ViewModels/ChatViewModel.swift` - Optimistic updates
- `swift_demo/Views/Chat/MessageBubbleView.swift` - Status indicators
- `swift_demo/Services/MessageService.swift` - Status update logic

## Code Structure Examples

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
    
    let recipientId: String
    let currentUserId: String
    let conversationId: String
    
    private let messageService = MessageService.shared
    private let localStorage = LocalStorageService.shared
    private let listenerService = FirestoreListenerService.shared
    
    init(recipientId: String) {
        self.recipientId = recipientId
        self.currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
        self.conversationId = ConversationService.shared.generateConversationId(
            userId1: currentUserId,
            userId2: recipientId
        )
        
        loadLocalMessages()
        startListening()
    }
    
    deinit {
        listenerService.stopListening(conversationId: conversationId)
    }
    
    func sendMessage(text: String) {
        guard !text.isEmpty else { return }
        
        let messageId = UUID().uuidString
        
        // 1. Optimistic insert - show immediately
        let optimisticMessage = MessageEntity(
            id: messageId,
            conversationId: conversationId,
            senderId: currentUserId,
            text: text,
            timestamp: Date(),
            status: .pending
        )
        
        messages.append(optimisticMessage)
        
        // 2. Send in background
        Task {
            do {
                // Save locally
                try localStorage.saveMessage(optimisticMessage)
                updateMessageStatus(messageId: messageId, status: .sent)
                
                // Send to Firestore
                try await messageService.sendToFirestore(
                    messageId: messageId,
                    text: text,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    recipientId: recipientId
                )
                
                // Status will update to .delivered via Firestore listener
                
            } catch {
                // Mark as failed
                updateMessageStatus(messageId: messageId, status: .failed)
                errorMessage = "Failed to send message"
                print("Error sending message: \(error)")
            }
        }
    }
    
    func retryMessage(messageId: String) {
        guard let message = messages.first(where: { $0.id == messageId }) else { return }
        
        // Update status to pending
        updateMessageStatus(messageId: messageId, status: .pending)
        
        Task {
            do {
                try await messageService.sendToFirestore(
                    messageId: messageId,
                    text: message.text,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    recipientId: recipientId
                )
                
                updateMessageStatus(messageId: messageId, status: .sent)
                
            } catch {
                updateMessageStatus(messageId: messageId, status: .failed)
                errorMessage = "Retry failed"
            }
        }
    }
    
    func deleteMessage(messageId: String) {
        messages.removeAll { $0.id == messageId }
        
        Task {
            try? localStorage.deleteMessage(messageId: messageId)
        }
    }
    
    private func updateMessageStatus(messageId: String, status: MessageStatus) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].status = status
            
            Task {
                try? localStorage.updateMessageStatus(messageId: messageId, status: status)
            }
        }
    }
    
    func loadLocalMessages() {
        do {
            messages = try localStorage.fetchMessages(for: conversationId)
        } catch {
            print("Error loading local messages: \(error)")
        }
    }
    
    private func startListening() {
        listenerService.listenToMessages(conversationId: conversationId) { [weak self] snapshot in
            guard let self = self else { return }
            
            Task {
                try? await self.messageService.syncMessageFromFirestore(snapshot)
                await MainActor.run {
                    self.loadLocalMessages()
                }
            }
        }
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
        case .sent:
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundColor(.secondary)
        case .delivered:
            Image(systemName: "checkmark.circle")
                .font(.caption2)
                .foregroundColor(.secondary)
        case .read:
            Image(systemName: "checkmark.circle.fill")
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

### FailedMessageActionsView.swift
```swift
import SwiftUI

struct FailedMessageActionsView: View {
    let onRetry: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onRetry) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(.top, 4)
    }
}
```

### MessageService.swift (Updated)
```swift
import Foundation
import FirebaseFirestore

class MessageService {
    static let shared = MessageService()
    private let db = Firestore.firestore()
    private let localStorage = LocalStorageService.shared
    
    func sendToFirestore(
        messageId: String,
        text: String,
        conversationId: String,
        senderId: String,
        recipientId: String
    ) async throws {
        let messageData: [String: Any] = [
            "id": messageId,
            "conversationId": conversationId,
            "senderId": senderId,
            "text": text,
            "timestamp": FieldValue.serverTimestamp(),
            "status": "delivered",
            "readBy": [senderId]
        ]
        
        try await db.collection("messages").document(messageId).setData(messageData)
        
        // Update conversation
        try await ConversationService.shared.updateConversation(
            conversationId: conversationId,
            lastMessage: text,
            participants: [senderId, recipientId]
        )
    }
    
    func syncMessageFromFirestore(_ snapshot: MessageSnapshot) async throws {
        // ... existing implementation ...
    }
}
```

## Acceptance Criteria
- [ ] Messages appear instantly when send button pressed
- [ ] Initial status is pending (with loading indicator)
- [ ] Status updates to sent after local save
- [ ] Status updates to delivered after Firestore confirmation
- [ ] Status transitions are smooth with animations
- [ ] Failed messages show red bubble
- [ ] Failed messages show retry and delete buttons
- [ ] Retry button resends message
- [ ] Delete button removes failed message
- [ ] No duplicate messages in UI
- [ ] Status icons clearly visible
- [ ] Works reliably under all conditions

## Testing
1. Log in and open chat
2. Send message with good network
3. Verify message appears immediately
4. Verify status progresses: pending → sent → delivered
5. Turn on airplane mode
6. Send message
7. Verify message appears but stays in pending
8. Turn off airplane mode (will test queue in PR-10)
9. Simulate network error (disconnect mid-send)
10. Verify message shows failed state
11. Tap retry button
12. Verify message resends
13. Tap delete button
14. Verify message removed

## Notes
- Optimistic UI is critical for good UX
- Users should never wait to see their message
- Clear status indicators build trust
- Failed state with retry is user-friendly
- Status transitions should be smooth
- Consider haptic feedback for status changes
- Test extensively with poor network

## Next PR
PR-10: Offline Message Queueing (depends on this PR)

