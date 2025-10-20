# PR-4: SwiftData Models & Local Persistence

## Overview
Implement SwiftData models for local message and conversation storage. Set up the SwiftData container and configure persistence.

## Dependencies
- PR-1: Project Setup & Firebase Configuration

## Tasks

### 1. Create SwiftData Models
- [ ] Create `Models/SwiftData/` folder
- [ ] Create `MessageEntity.swift`
  - [ ] @Model macro
  - [ ] Properties: id, conversationId, senderId, text, timestamp, status, readBy
  - [ ] Relationship to ConversationEntity
  - [ ] Computed properties for status checks
- [ ] Create `ConversationEntity.swift`
  - [ ] @Model macro
  - [ ] Properties: id, participantIds, isGroup, lastMessageText, lastMessageTime, unreadCount
  - [ ] Relationship to MessageEntity (one-to-many)
  - [ ] Delete rule: cascade
- [ ] Create `QueuedMessageEntity.swift`
  - [ ] @Model macro
  - [ ] Properties: id, conversationId, text, timestamp, retryCount, lastRetryTime
  - [ ] For offline message queue

### 2. Create Message Status Enum
- [ ] Create `Models/MessageStatus.swift`
  - [ ] Enum: pending, sent, delivered, read, failed
  - [ ] Codable conformance
  - [ ] Display text/icon helpers

### 3. Set Up SwiftData Container
- [ ] Create `Services/PersistenceController.swift`
  - [ ] Configure ModelContainer
  - [ ] Configure ModelContext
  - [ ] Include all models in schema
  - [ ] Error handling for initialization
  - [ ] Singleton pattern

### 4. Integrate SwiftData with App
- [ ] Update `swift_demoApp.swift`
  - [ ] Initialize ModelContainer
  - [ ] Add modelContainer modifier to WindowGroup
  - [ ] Handle initialization errors

### 5. Create Data Access Layer
- [ ] Create `Services/LocalStorageService.swift`
  - [ ] Methods to save messages locally
  - [ ] Methods to fetch messages for conversation
  - [ ] Methods to update message status
  - [ ] Methods to save/fetch conversations
  - [ ] Methods to manage message queue
  - [ ] Methods to update unread counts

### 6. Create Helper Extensions
- [ ] Create extensions for date formatting
- [ ] Create extensions for model conversions (Firestore ↔ SwiftData)

## Files to Create/Modify

### New Files
- `swift_demo/Models/SwiftData/MessageEntity.swift`
- `swift_demo/Models/SwiftData/ConversationEntity.swift`
- `swift_demo/Models/SwiftData/QueuedMessageEntity.swift`
- `swift_demo/Models/MessageStatus.swift`
- `swift_demo/Services/PersistenceController.swift`
- `swift_demo/Services/LocalStorageService.swift`

### Modified Files
- `swift_demo/swift_demoApp.swift` - Add SwiftData container

## Code Structure Examples

### MessageEntity.swift
```swift
import Foundation
import SwiftData

@Model
final class MessageEntity {
    @Attribute(.unique) var id: String
    var conversationId: String
    var senderId: String
    var text: String
    var timestamp: Date
    var statusRaw: String
    var readBy: [String]
    
    @Relationship(deleteRule: .nullify, inverse: \ConversationEntity.messages)
    var conversation: ConversationEntity?
    
    var status: MessageStatus {
        get { MessageStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
    
    init(id: String, conversationId: String, senderId: String, text: String, 
         timestamp: Date, status: MessageStatus, readBy: [String] = []) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.text = text
        self.timestamp = timestamp
        self.statusRaw = status.rawValue
        self.readBy = readBy
    }
}
```

### ConversationEntity.swift
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

### QueuedMessageEntity.swift
```swift
import Foundation
import SwiftData

@Model
final class QueuedMessageEntity {
    @Attribute(.unique) var id: String
    var conversationId: String
    var text: String
    var timestamp: Date
    var retryCount: Int
    var lastRetryTime: Date?
    
    init(id: String, conversationId: String, text: String, timestamp: Date) {
        self.id = id
        self.conversationId = conversationId
        self.text = text
        self.timestamp = timestamp
        self.retryCount = 0
    }
}
```

### MessageStatus.swift
```swift
import Foundation

enum MessageStatus: String, Codable {
    case pending
    case sent
    case delivered
    case read
    case failed
    
    var displayText: String {
        switch self {
        case .pending: return "Sending..."
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .read: return "Read"
        case .failed: return "Failed"
        }
    }
    
    var iconName: String {
        switch self {
        case .pending: return "clock"
        case .sent: return "checkmark"
        case .delivered: return "checkmark.circle"
        case .read: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle"
        }
    }
}
```

### PersistenceController.swift
```swift
import Foundation
import SwiftData

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: ModelContainer
    
    init() {
        let schema = Schema([
            MessageEntity.self,
            ConversationEntity.self,
            QueuedMessageEntity.self
        ])
        
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }
}
```

### LocalStorageService.swift
```swift
import Foundation
import SwiftData

@MainActor
class LocalStorageService {
    static let shared = LocalStorageService()
    
    private let modelContext: ModelContext
    
    init() {
        self.modelContext = PersistenceController.shared.container.mainContext
    }
    
    func saveMessage(_ message: MessageEntity) throws {
        modelContext.insert(message)
        try modelContext.save()
    }
    
    func fetchMessages(for conversationId: String) throws -> [MessageEntity] {
        let predicate = #Predicate<MessageEntity> { $0.conversationId == conversationId }
        let descriptor = FetchDescriptor<MessageEntity>(predicate: predicate, sortBy: [SortDescriptor(\.timestamp)])
        return try modelContext.fetch(descriptor)
    }
    
    func updateMessageStatus(messageId: String, status: MessageStatus) throws {
        // Implementation
    }
    
    func saveConversation(_ conversation: ConversationEntity) throws {
        // Implementation
    }
    
    func fetchAllConversations() throws -> [ConversationEntity] {
        // Implementation
    }
    
    func queueMessage(_ message: QueuedMessageEntity) throws {
        // Implementation
    }
    
    func getQueuedMessages() throws -> [QueuedMessageEntity] {
        // Implementation
    }
}
```

## Acceptance Criteria
- [ ] SwiftData models defined correctly
- [ ] ModelContainer initialized successfully
- [ ] Can save messages to local storage
- [ ] Can fetch messages from local storage
- [ ] Can update message status
- [ ] Can save and fetch conversations
- [ ] Can queue messages for offline sending
- [ ] Data persists across app restarts
- [ ] Relationships between models work correctly
- [ ] No data corruption or crashes

## Testing
1. Run app in Simulator
2. Insert test message into SwiftData
3. Fetch message and verify data
4. Update message status
5. Force quit app and reopen
6. Verify data persists
7. Test relationship: conversation with messages
8. Test queued message storage and retrieval

## Notes
- SwiftData requires iOS 17+
- Use @Model macro for SwiftData entities
- Relationships handle cascade deletes automatically
- ModelContext is main thread only by default
- Keep Firestore and SwiftData models separate but convertible
- Message queue is critical for offline functionality

## Next PR
PR-5: User Profile & Online Status (parallel with PR-4)

