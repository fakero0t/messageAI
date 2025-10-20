# PR-7: Message Sending (Basic - Online Only)

## Overview
Implement actual message sending to Firestore and local SwiftData storage. Focus on online-only scenario first, offline queueing comes later.

## Dependencies
- PR-4: SwiftData Models & Local Persistence
- PR-6: One-on-One Chat UI

## Tasks

### 1. Create Message Service
- [ ] Create `Services/MessageService.swift`
  - [ ] Method to send message to Firestore
  - [ ] Method to save message to local SwiftData
  - [ ] Generate unique message IDs (UUID)
  - [ ] Use server timestamps in Firestore
  - [ ] Handle send errors
  - [ ] Update message status after send

### 2. Define Firestore Schema
- [ ] Document Firestore collections structure
  - [ ] `conversations/{conversationId}` collection
  - [ ] `messages/{messageId}` collection or subcollection
  - [ ] Message document fields
  - [ ] Conversation document fields

### 3. Implement Send Flow
- [ ] Update `ChatViewModel.swift`
  - [ ] Replace mock sendMessage with real implementation
  - [ ] Call MessageService to send
  - [ ] Optimistic insert to local messages array
  - [ ] Save to SwiftData
  - [ ] Send to Firestore
  - [ ] Handle success/failure

### 4. Create/Update Conversation
- [ ] Create conversation document if doesn't exist
  - [ ] On first message, create conversation
  - [ ] Store participant IDs
  - [ ] Store isGroup flag
  - [ ] Update lastMessage info
- [ ] Update existing conversation on new message
  - [ ] Update lastMessageText
  - [ ] Update lastMessageTime

### 5. Implement Message Status Updates
- [ ] Set initial status to .pending
- [ ] Update to .sent after local save
- [ ] Update to .delivered after Firestore confirmation
- [ ] Update UI to reflect status changes

### 6. Add Error Handling
- [ ] Handle Firestore write errors
- [ ] Handle SwiftData save errors
- [ ] Display error messages to user
- [ ] Keep message in pending state if failed
- [ ] Don't lose messages on error

### 7. Create Conversation Service
- [ ] Create `Services/ConversationService.swift`
  - [ ] Method to create conversation
  - [ ] Method to update conversation
  - [ ] Method to fetch conversation
  - [ ] Handle conversation metadata

## Files to Create/Modify

### New Files
- `swift_demo/Services/MessageService.swift`
- `swift_demo/Services/ConversationService.swift`

### Modified Files
- `swift_demo/ViewModels/ChatViewModel.swift` - Real message sending
- `swift_demo/Services/LocalStorageService.swift` - Additional methods if needed

## Code Structure Examples

### MessageService.swift
```swift
import Foundation
import FirebaseFirestore

class MessageService {
    static let shared = MessageService()
    private let db = Firestore.firestore()
    private let localStorage = LocalStorageService.shared
    
    func sendMessage(
        text: String,
        conversationId: String,
        senderId: String,
        recipientId: String
    ) async throws -> String {
        let messageId = UUID().uuidString
        
        // 1. Create message entity for local storage
        let message = MessageEntity(
            id: messageId,
            conversationId: conversationId,
            senderId: senderId,
            text: text,
            timestamp: Date(),
            status: .pending
        )
        
        // 2. Save to local SwiftData first
        try await MainActor.run {
            try localStorage.saveMessage(message)
            try localStorage.updateMessageStatus(messageId: messageId, status: .sent)
        }
        
        // 3. Send to Firestore
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
        
        // 4. Update local status to delivered
        try await MainActor.run {
            try localStorage.updateMessageStatus(messageId: messageId, status: .delivered)
        }
        
        // 5. Update conversation
        try await ConversationService.shared.updateConversation(
            conversationId: conversationId,
            lastMessage: text,
            participants: [senderId, recipientId]
        )
        
        return messageId
    }
}
```

### ConversationService.swift
```swift
import Foundation
import FirebaseFirestore

class ConversationService {
    static let shared = ConversationService()
    private let db = Firestore.firestore()
    private let localStorage = LocalStorageService.shared
    
    func updateConversation(
        conversationId: String,
        lastMessage: String,
        participants: [String]
    ) async throws {
        let conversationRef = db.collection("conversations").document(conversationId)
        
        let conversationData: [String: Any] = [
            "id": conversationId,
            "participants": participants,
            "isGroup": false,
            "lastMessageText": lastMessage,
            "lastMessageTime": FieldValue.serverTimestamp()
        ]
        
        // Use merge to create or update
        try await conversationRef.setData(conversationData, merge: true)
        
        // Update local storage
        try await MainActor.run {
            let conversation = ConversationEntity(
                id: conversationId,
                participantIds: participants,
                isGroup: false
            )
            conversation.lastMessageText = lastMessage
            conversation.lastMessageTime = Date()
            
            try localStorage.saveConversation(conversation)
        }
    }
    
    func getOrCreateConversation(
        userId1: String,
        userId2: String
    ) async throws -> String {
        let conversationId = generateConversationId(userId1: userId1, userId2: userId2)
        
        let conversationRef = db.collection("conversations").document(conversationId)
        let snapshot = try await conversationRef.getDocument()
        
        if !snapshot.exists {
            // Create new conversation
            let conversationData: [String: Any] = [
                "id": conversationId,
                "participants": [userId1, userId2],
                "isGroup": false
            ]
            try await conversationRef.setData(conversationData)
        }
        
        return conversationId
    }
    
    func generateConversationId(userId1: String, userId2: String) -> String {
        let sorted = [userId1, userId2].sorted()
        return sorted.joined(separator: "_")
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
    
    let recipientId: String
    let currentUserId: String
    let conversationId: String
    
    private let messageService = MessageService.shared
    private let localStorage = LocalStorageService.shared
    
    init(recipientId: String) {
        self.recipientId = recipientId
        self.currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
        self.conversationId = ConversationService.shared.generateConversationId(
            userId1: currentUserId,
            userId2: recipientId
        )
        
        loadLocalMessages()
    }
    
    func sendMessage(text: String) {
        guard !text.isEmpty, !isSending else { return }
        
        isSending = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await messageService.sendMessage(
                    text: text,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    recipientId: recipientId
                )
                
                // Reload messages to show updated status
                loadLocalMessages()
                
            } catch {
                errorMessage = "Failed to send message: \(error.localizedDescription)"
                print("Error sending message: \(error)")
            }
            
            isSending = false
        }
    }
    
    func loadLocalMessages() {
        do {
            messages = try localStorage.fetchMessages(for: conversationId)
        } catch {
            print("Error loading local messages: \(error)")
        }
    }
}
```

## Firestore Schema Documentation

### Messages Collection
```
messages/{messageId}
  - id: string (UUID)
  - conversationId: string
  - senderId: string (user ID)
  - text: string
  - timestamp: timestamp (server)
  - status: string (delivered, read)
  - readBy: array<string> (user IDs)
```

### Conversations Collection
```
conversations/{conversationId}
  - id: string (userId1_userId2, sorted)
  - participants: array<string> (user IDs)
  - isGroup: boolean
  - lastMessageText: string
  - lastMessageTime: timestamp
```

## Acceptance Criteria
- [ ] Messages send to Firestore successfully
- [ ] Messages save to local SwiftData
- [ ] Message status updates: pending → sent → delivered
- [ ] Conversation created on first message
- [ ] Conversation updated with last message info
- [ ] Message appears in chat immediately (optimistic)
- [ ] Status indicator updates after confirmation
- [ ] Errors handled gracefully
- [ ] Error messages shown to user
- [ ] No duplicate messages
- [ ] Unique message IDs generated
- [ ] Server timestamps used in Firestore

## Testing
1. Log in as User A
2. Navigate to chat with User B
3. Type and send message
4. Verify message appears immediately with pending/sent status
5. Check Firestore Console → messages collection → verify message exists
6. Check Firestore Console → conversations collection → verify conversation updated
7. Verify message status updates to "delivered"
8. Send multiple messages rapidly
9. Verify all messages send successfully
10. Force quit app and reopen
11. Verify messages persist in SwiftData

## Notes
- This PR focuses on online-only sending
- Offline queueing will be added in PR-10
- Use optimistic UI for better UX
- Server timestamps prevent clock skew issues
- Message IDs must be unique and generated client-side
- Conversation ID is deterministic (sorted user IDs)
- Status tracking is essential for reliability

## Next PR
PR-8: Real-Time Message Receiving (depends on this PR)

