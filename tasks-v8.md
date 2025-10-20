# PR-8: Real-Time Message Receiving

## Overview
Implement real-time Firestore listeners to receive messages as they arrive. Sync messages between Firestore and local SwiftData storage.

## Dependencies
- PR-7: Message Sending (Basic - Online Only)

## Tasks

### 1. Create Firestore Listener Service
- [ ] Create `Services/FirestoreListenerService.swift`
  - [ ] Method to start listening to messages for conversation
  - [ ] Method to stop listening
  - [ ] Handle listener lifecycle
  - [ ] Parse incoming message snapshots
  - [ ] Filter out own messages if needed

### 2. Implement Message Sync
- [ ] Update `Services/MessageService.swift`
  - [ ] Method to sync Firestore message to local SwiftData
  - [ ] Check if message already exists locally
  - [ ] Save new messages to SwiftData
  - [ ] Update existing messages if status changed
  - [ ] Handle deduplication

### 3. Update ChatViewModel
- [ ] Modify `ViewModels/ChatViewModel.swift`
  - [ ] Start Firestore listener on init
  - [ ] Stop listener on deinit
  - [ ] Update messages array when new messages arrive
  - [ ] Maintain scroll position or auto-scroll
  - [ ] Handle message updates (status changes)

### 4. Handle Real-Time Updates
- [ ] Listen to conversation's messages
  - [ ] Query messages by conversationId
  - [ ] Order by timestamp
  - [ ] Limit initial load (e.g., last 50 messages)
  - [ ] Handle added, modified, removed events

### 5. Implement Message Deduplication
- [ ] Check message ID before inserting
- [ ] Update local message if Firestore version is newer
- [ ] Prevent duplicate display in UI
- [ ] Handle race conditions (sent before received confirmation)

### 6. Update Conversation List
- [ ] Listen to conversations collection
  - [ ] Filter by current user in participants
  - [ ] Order by lastMessageTime
  - [ ] Update conversation list in real-time

### 7. Handle Listener Errors
- [ ] Reconnection logic on listener failure
- [ ] Exponential backoff for errors
- [ ] Notify user of connection issues
- [ ] Fallback to local data when offline

### 8. Optimize Performance
- [ ] Pagination for message history
- [ ] Lazy loading older messages
- [ ] Limit active listeners
- [ ] Clean up listeners properly

## Files to Create/Modify

### New Files
- `swift_demo/Services/FirestoreListenerService.swift`

### Modified Files
- `swift_demo/Services/MessageService.swift` - Add sync methods
- `swift_demo/ViewModels/ChatViewModel.swift` - Add listeners
- `swift_demo/Services/LocalStorageService.swift` - Add upsert methods

## Code Structure Examples

### FirestoreListenerService.swift
```swift
import Foundation
import FirebaseFirestore
import Combine

class FirestoreListenerService {
    static let shared = FirestoreListenerService()
    private let db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    
    func listenToMessages(
        conversationId: String,
        onMessage: @escaping (MessageSnapshot) -> Void
    ) {
        // Remove existing listener if any
        stopListening(conversationId: conversationId)
        
        let listener = db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening to messages: \(error)")
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                snapshot.documentChanges.forEach { change in
                    if change.type == .added || change.type == .modified {
                        do {
                            let messageData = change.document.data()
                            let messageSnapshot = try self.parseMessage(from: messageData)
                            onMessage(messageSnapshot)
                        } catch {
                            print("Error parsing message: \(error)")
                        }
                    }
                }
            }
        
        listeners[conversationId] = listener
    }
    
    func stopListening(conversationId: String) {
        listeners[conversationId]?.remove()
        listeners.removeValue(forKey: conversationId)
    }
    
    func stopAllListeners() {
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    private func parseMessage(from data: [String: Any]) throws -> MessageSnapshot {
        let id = data["id"] as? String ?? ""
        let conversationId = data["conversationId"] as? String ?? ""
        let senderId = data["senderId"] as? String ?? ""
        let text = data["text"] as? String ?? ""
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        let status = data["status"] as? String ?? "delivered"
        let readBy = data["readBy"] as? [String] ?? []
        
        return MessageSnapshot(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            text: text,
            timestamp: timestamp,
            status: status,
            readBy: readBy
        )
    }
}

struct MessageSnapshot {
    let id: String
    let conversationId: String
    let senderId: String
    let text: String
    let timestamp: Date
    let status: String
    let readBy: [String]
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
    
    // ... existing sendMessage method ...
    
    func syncMessageFromFirestore(_ snapshot: MessageSnapshot) async throws {
        await MainActor.run {
            do {
                // Check if message exists locally
                let existingMessages = try localStorage.fetchMessages(for: snapshot.conversationId)
                let exists = existingMessages.contains { $0.id == snapshot.id }
                
                if exists {
                    // Update existing message
                    try localStorage.updateMessage(
                        messageId: snapshot.id,
                        status: MessageStatus(rawValue: snapshot.status) ?? .delivered,
                        readBy: snapshot.readBy
                    )
                } else {
                    // Insert new message
                    let message = MessageEntity(
                        id: snapshot.id,
                        conversationId: snapshot.conversationId,
                        senderId: snapshot.senderId,
                        text: snapshot.text,
                        timestamp: snapshot.timestamp,
                        status: MessageStatus(rawValue: snapshot.status) ?? .delivered,
                        readBy: snapshot.readBy
                    )
                    try localStorage.saveMessage(message)
                }
            } catch {
                print("Error syncing message: \(error)")
            }
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
        // ... existing implementation ...
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

### LocalStorageService.swift (Add Methods)
```swift
@MainActor
class LocalStorageService {
    // ... existing methods ...
    
    func updateMessage(messageId: String, status: MessageStatus, readBy: [String]) throws {
        let predicate = #Predicate<MessageEntity> { $0.id == messageId }
        let descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
        
        if let message = try modelContext.fetch(descriptor).first {
            message.status = status
            message.readBy = readBy
            try modelContext.save()
        }
    }
}
```

## Acceptance Criteria
- [ ] Messages from other users appear in real-time
- [ ] Firestore listener starts when chat opens
- [ ] Listener stops when chat closes
- [ ] New messages sync to local SwiftData
- [ ] No duplicate messages in UI
- [ ] Message status updates appear in real-time
- [ ] Messages load from local storage first (fast)
- [ ] Firestore updates supplement local data
- [ ] Works with multiple devices sending to same conversation
- [ ] No memory leaks from listeners
- [ ] Listeners clean up properly

## Testing
1. Log in as User A on Device 1
2. Log in as User B on Device 2
3. Open chat between A and B on Device 1
4. Send message from Device 2 to User A
5. Verify message appears on Device 1 within 1 second
6. Send message from Device 1 to User B
7. Verify message appears on Device 2 within 1 second
8. Send 5 messages rapidly from each device
9. Verify all messages appear on both devices in correct order
10. Close chat on Device 1
11. Send message from Device 2
12. Reopen chat on Device 1
13. Verify message is there (loaded from local storage)

## Notes
- Firestore listeners provide real-time updates
- Always load from local storage first for speed
- Firestore syncs in background
- Deduplication is critical
- Listener cleanup prevents memory leaks
- Use snapshot listeners, not .get() polling
- Consider pagination for large message history
- Server timestamps ensure correct ordering

## Next PR
PR-9: Optimistic UI & Message Status (depends on this PR)

