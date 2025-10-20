# PR-10: Offline Message Queueing

## Overview
Implement offline message queueing system. Messages sent while offline should queue locally and automatically send when connectivity returns.

## Dependencies
- PR-9: Optimistic UI & Message Status

## Tasks

### 1. Create Queue Service
- [ ] Create `Services/MessageQueueService.swift`
  - [ ] Add message to queue
  - [ ] Process queue when online
  - [ ] Persist queue in SwiftData (already have QueuedMessageEntity)
  - [ ] Handle queue ordering
  - [ ] Retry failed queue items
  - [ ] Remove from queue after successful send

### 2. Detect Network Connectivity
- [ ] Create `Services/NetworkMonitor.swift`
  - [ ] Use Network framework
  - [ ] Observable network status
  - [ ] Notify when connectivity changes
  - [ ] Track connection type (WiFi, Cellular, None)
  - [ ] Publish network status updates

### 3. Integrate Queue with Message Sending
- [ ] Update `ChatViewModel.swift`
  - [ ] Check network status before sending
  - [ ] If offline, add to queue instead
  - [ ] Show queued status in UI
  - [ ] Auto-process queue when back online

### 4. Implement Queue Processing
- [ ] Process queue on network restored
- [ ] Process queue on app foreground
- [ ] Process queue items in order
- [ ] Handle partial queue failures
- [ ] Exponential backoff for retries
- [ ] Max retry attempts

### 5. Update UI for Queue Status
- [ ] Show indicator for queued messages
- [ ] Display "Queued - will send when online" status
- [ ] Update conversation list with queue count
- [ ] Show connectivity status in app

### 6. Handle App Lifecycle
- [ ] Process queue on app launch
- [ ] Check for pending messages
- [ ] Auto-send queued messages
- [ ] Handle app background/foreground

### 7. Create Queue Management Methods
- [ ] Clear queue after successful send
- [ ] Update queue item retry count
- [ ] Remove queue item
- [ ] Get all queued messages
- [ ] Get queue count

### 8. Test Edge Cases
- [ ] Multiple queued messages
- [ ] Queue persistence across app restarts
- [ ] Mixed success/failure in queue
- [ ] Network flapping (on/off rapidly)

## Files to Create/Modify

### New Files
- `swift_demo/Services/MessageQueueService.swift`
- `swift_demo/Services/NetworkMonitor.swift`
- `swift_demo/Views/Components/NetworkStatusView.swift`

### Modified Files
- `swift_demo/ViewModels/ChatViewModel.swift` - Queue integration
- `swift_demo/Models/MessageStatus.swift` - Add .queued status
- `swift_demo/Services/LocalStorageService.swift` - Queue methods
- `swift_demo/swift_demoApp.swift` - Initialize NetworkMonitor

## Code Structure Examples

### NetworkMonitor.swift
```swift
import Foundation
import Network
import Combine

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
                
                if path.status == .satisfied {
                    // Network restored - notify queue service
                    NotificationCenter.default.post(name: .networkRestored, object: nil)
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
}

extension Notification.Name {
    static let networkRestored = Notification.Name("networkRestored")
}
```

### MessageQueueService.swift
```swift
import Foundation
import SwiftData
import Combine

@MainActor
class MessageQueueService: ObservableObject {
    static let shared = MessageQueueService()
    
    @Published var queueCount = 0
    @Published var isProcessing = false
    
    private let localStorage = LocalStorageService.shared
    private let messageService = MessageService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private let maxRetries = 5
    
    init() {
        setupNetworkObserver()
    }
    
    func queueMessage(
        id: String,
        conversationId: String,
        text: String,
        recipientId: String
    ) throws {
        let queuedMessage = QueuedMessageEntity(
            id: id,
            conversationId: conversationId,
            text: text,
            timestamp: Date()
        )
        
        try localStorage.queueMessage(queuedMessage)
        updateQueueCount()
    }
    
    func processQueue() async {
        guard !isProcessing else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let queuedMessages = try localStorage.getQueuedMessages()
            
            for queuedMessage in queuedMessages {
                // Check retry count
                if queuedMessage.retryCount >= maxRetries {
                    // Mark as failed and remove from queue
                    try markMessageAsFailed(queuedMessage)
                    continue
                }
                
                do {
                    // Attempt to send
                    let conversationId = queuedMessage.conversationId
                    let participants = conversationId.split(separator: "_").map(String.init)
                    
                    guard participants.count == 2 else { continue }
                    
                    let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
                    let recipientId = participants.first { $0 != currentUserId } ?? ""
                    
                    try await messageService.sendToFirestore(
                        messageId: queuedMessage.id,
                        text: queuedMessage.text,
                        conversationId: queuedMessage.conversationId,
                        senderId: currentUserId,
                        recipientId: recipientId
                    )
                    
                    // Success - remove from queue
                    try localStorage.removeQueuedMessage(queuedMessage.id)
                    
                    // Update message status to delivered
                    try localStorage.updateMessageStatus(
                        messageId: queuedMessage.id,
                        status: .delivered
                    )
                    
                } catch {
                    // Failed - increment retry count
                    queuedMessage.retryCount += 1
                    queuedMessage.lastRetryTime = Date()
                    try localStorage.updateQueuedMessage(queuedMessage)
                    
                    print("Failed to send queued message: \(error)")
                }
            }
            
            updateQueueCount()
            
        } catch {
            print("Error processing queue: \(error)")
        }
    }
    
    private func markMessageAsFailed(_ queuedMessage: QueuedMessageEntity) throws {
        try localStorage.updateMessageStatus(
            messageId: queuedMessage.id,
            status: .failed
        )
        try localStorage.removeQueuedMessage(queuedMessage.id)
    }
    
    private func updateQueueCount() {
        do {
            let queued = try localStorage.getQueuedMessages()
            queueCount = queued.count
        } catch {
            queueCount = 0
        }
    }
    
    private func setupNetworkObserver() {
        NotificationCenter.default.publisher(for: .networkRestored)
            .sink { [weak self] _ in
                Task {
                    await self?.processQueue()
                }
            }
            .store(in: &cancellables)
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
    }
    
    deinit {
        listenerService.stopListening(conversationId: conversationId)
    }
    
    func sendMessage(text: String) {
        guard !text.isEmpty else { return }
        
        let messageId = UUID().uuidString
        
        // Determine status based on network
        let initialStatus: MessageStatus = networkMonitor.isConnected ? .pending : .queued
        
        // 1. Optimistic insert
        let optimisticMessage = MessageEntity(
            id: messageId,
            conversationId: conversationId,
            senderId: currentUserId,
            text: text,
            timestamp: Date(),
            status: initialStatus
        )
        
        messages.append(optimisticMessage)
        
        // 2. Handle based on network status
        if networkMonitor.isConnected {
            sendOnline(messageId: messageId, text: text)
        } else {
            sendOffline(messageId: messageId, text: text)
        }
    }
    
    private func sendOnline(messageId: String, text: String) {
        Task {
            do {
                // Save locally
                let message = MessageEntity(
                    id: messageId,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    text: text,
                    timestamp: Date(),
                    status: .pending
                )
                try localStorage.saveMessage(message)
                updateMessageStatus(messageId: messageId, status: .sent)
                
                // Send to Firestore
                try await messageService.sendToFirestore(
                    messageId: messageId,
                    text: text,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    recipientId: recipientId
                )
                
            } catch {
                // If send fails, queue it
                updateMessageStatus(messageId: messageId, status: .queued)
                try? queueService.queueMessage(
                    id: messageId,
                    conversationId: conversationId,
                    text: text,
                    recipientId: recipientId
                )
            }
        }
    }
    
    private func sendOffline(messageId: String, text: String) {
        Task {
            do {
                // Save locally
                let message = MessageEntity(
                    id: messageId,
                    conversationId: conversationId,
                    senderId: currentUserId,
                    text: text,
                    timestamp: Date(),
                    status: .queued
                )
                try localStorage.saveMessage(message)
                
                // Add to queue
                try queueService.queueMessage(
                    id: messageId,
                    conversationId: conversationId,
                    text: text,
                    recipientId: recipientId
                )
                
            } catch {
                updateMessageStatus(messageId: messageId, status: .failed)
                errorMessage = "Failed to queue message"
            }
        }
    }
    
    private func observeNetwork() {
        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                self?.isOffline = !isConnected
                
                // Process queue when coming back online
                if isConnected {
                    Task {
                        await self?.queueService.processQueue()
                        self?.loadLocalMessages()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // ... other existing methods ...
}
```

### MessageStatus.swift (Updated)
```swift
import Foundation

enum MessageStatus: String, Codable {
    case pending
    case sent
    case queued  // New status
    case delivered
    case read
    case failed
    
    var displayText: String {
        switch self {
        case .pending: return "Sending..."
        case .sent: return "Sent"
        case .queued: return "Queued"
        case .delivered: return "Delivered"
        case .read: return "Read"
        case .failed: return "Failed"
        }
    }
    
    var iconName: String {
        switch self {
        case .pending: return "clock"
        case .sent: return "checkmark"
        case .queued: return "clock.arrow.circlepath"
        case .delivered: return "checkmark.circle"
        case .read: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle"
        }
    }
}
```

### NetworkStatusView.swift
```swift
import SwiftUI

struct NetworkStatusView: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @ObservedObject var queueService = MessageQueueService.shared
    
    var body: some View {
        if !networkMonitor.isConnected || queueService.queueCount > 0 {
            HStack {
                Image(systemName: networkMonitor.isConnected ? "wifi" : "wifi.slash")
                    .foregroundColor(networkMonitor.isConnected ? .orange : .red)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
    
    private var statusText: String {
        if !networkMonitor.isConnected {
            return "Offline"
        } else if queueService.queueCount > 0 {
            return "Sending \(queueService.queueCount) message(s)..."
        }
        return ""
    }
}
```

## Acceptance Criteria
- [ ] Messages queue when sent offline
- [ ] Queued messages persist across app restarts
- [ ] Queue processes automatically when network restored
- [ ] Queue processes on app launch
- [ ] Queued status shows in UI
- [ ] Queue count displayed in conversation list
- [ ] Messages send in correct order
- [ ] Failed queue items marked appropriately
- [ ] Max retry limit enforced
- [ ] Network status indicator shows in UI
- [ ] No messages lost when offline

## Testing
1. Log in and open chat
2. Enable airplane mode
3. Send 3 messages
4. Verify messages show "queued" status
5. Force quit app
6. Reopen app (still offline)
7. Verify queued messages still present
8. Disable airplane mode
9. Verify messages send automatically
10. Verify status updates to delivered
11. Test rapid network on/off
12. Test queue with multiple conversations

## Notes
- Queue is critical for reliability
- Must persist across app restarts
- Process queue on network restored
- Process queue on app foreground
- Handle partial failures gracefully
- Exponential backoff prevents spam
- Max retries prevent infinite loops
- Queue ordering matters

## Next PR
PR-11: Network Monitoring & Resilience (depends on this PR)

