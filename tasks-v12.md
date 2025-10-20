# PR-12: Crash Recovery & Message Retry

## Overview
Ensure no messages are lost if the app crashes during send. Implement recovery mechanism to detect and send unsent messages on app launch.

## Dependencies
- PR-11: Network Monitoring & Resilience

## Tasks

### 1. Implement Crash Recovery Service
- [ ] Create `Services/CrashRecoveryService.swift`
  - [ ] Check for unsent messages on app launch
  - [ ] Detect messages in pending/sent state
  - [ ] Queue or retry unsent messages
  - [ ] Handle partial sends

### 2. Add App Launch Recovery
- [ ] Update `swift_demoApp.swift`
  - [ ] Initialize crash recovery service
  - [ ] Run recovery check on launch
  - [ ] Process unsent messages
  - [ ] Log recovery actions

### 3. Detect Unsent Messages
- [ ] Query SwiftData for messages with status pending/sent
  - [ ] Filter messages older than threshold (e.g., 5 seconds)
  - [ ] Assume these may have failed due to crash
  - [ ] Add to queue for retry

### 4. Handle Message Deduplication
- [ ] Prevent duplicate sends after recovery
  - [ ] Check if message already in Firestore
  - [ ] Use message ID for deduplication
  - [ ] Update local status if already sent

### 5. Implement Idempotent Message IDs
- [ ] Ensure message IDs are generated before send
  - [ ] Use UUID generated client-side
  - [ ] ID persists through crashes
  - [ ] Firestore uses same ID

### 6. Add Recovery Logging
- [ ] Log recovery actions
  - [ ] Messages found for recovery
  - [ ] Recovery success/failure
  - [ ] Help debugging

### 7. Handle Edge Cases
- [ ] Message saved locally but not sent
- [ ] Message sent to Firestore but status not updated
- [ ] Message partially sent (conversation updated but not message)
- [ ] Multiple crashes in succession

### 8. Test Crash Scenarios
- [ ] Force quit during send
- [ ] Crash simulator during operations
- [ ] Multiple messages in flight during crash
- [ ] Recovery after crash in offline state

## Files to Create/Modify

### New Files
- `swift_demo/Services/CrashRecoveryService.swift`

### Modified Files
- `swift_demo/swift_demoApp.swift` - Initialize recovery
- `swift_demo/Services/LocalStorageService.swift` - Recovery queries
- `swift_demo/Services/MessageQueueService.swift` - Integrate recovery

## Code Structure Examples

### CrashRecoveryService.swift
```swift
import Foundation
import SwiftData

@MainActor
class CrashRecoveryService {
    static let shared = CrashRecoveryService()
    
    private let localStorage = LocalStorageService.shared
    private let queueService = MessageQueueService.shared
    private let messageService = MessageService.shared
    
    // Messages older than this threshold are considered potentially failed
    private let staleThreshold: TimeInterval = 5.0 // 5 seconds
    
    func performRecovery() async {
        print("🔄 Starting crash recovery...")
        
        do {
            // Find stale messages that may have failed
            let staleMessages = try findStaleMessages()
            
            guard !staleMessages.isEmpty else {
                print("✅ No stale messages found")
                return
            }
            
            print("⚠️ Found \(staleMessages.count) potentially failed message(s)")
            
            for message in staleMessages {
                await recoverMessage(message)
            }
            
            print("✅ Crash recovery complete")
            
        } catch {
            print("❌ Crash recovery failed: \(error)")
        }
    }
    
    private func findStaleMessages() throws -> [MessageEntity] {
        // Find messages with pending or sent status older than threshold
        let thresholdDate = Date().addingTimeInterval(-staleThreshold)
        
        let predicate = #Predicate<MessageEntity> { message in
            (message.statusRaw == "pending" || message.statusRaw == "sent") &&
            message.timestamp < thresholdDate
        }
        
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp)]
        )
        
        return try localStorage.modelContext.fetch(descriptor)
    }
    
    private func recoverMessage(_ message: MessageEntity) async {
        print("🔄 Recovering message: \(message.id)")
        
        // Check if message already exists in Firestore
        let existsInFirestore = await checkFirestoreForMessage(message.id)
        
        if existsInFirestore {
            // Message made it to Firestore - just update local status
            print("✅ Message found in Firestore, updating local status")
            try? localStorage.updateMessageStatus(messageId: message.id, status: .delivered)
        } else {
            // Message didn't make it - queue for retry
            print("⚠️ Message not in Firestore, queueing for retry")
            
            do {
                // Add to queue
                try queueService.queueMessage(
                    id: message.id,
                    conversationId: message.conversationId,
                    text: message.text,
                    recipientId: extractRecipientId(from: message.conversationId)
                )
                
                // Update status to queued
                try localStorage.updateMessageStatus(messageId: message.id, status: .queued)
                
            } catch {
                print("❌ Failed to queue message: \(error)")
                // Mark as failed
                try? localStorage.updateMessageStatus(messageId: message.id, status: .failed)
            }
        }
    }
    
    private func checkFirestoreForMessage(_ messageId: String) async -> Bool {
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("messages").document(messageId).getDocument()
            return snapshot.exists
        } catch {
            print("Error checking Firestore: \(error)")
            return false
        }
    }
    
    private func extractRecipientId(from conversationId: String) -> String {
        let participants = conversationId.split(separator: "_").map(String.init)
        let currentUserId = AuthenticationService.shared.currentUser?.id ?? ""
        return participants.first { $0 != currentUserId } ?? ""
    }
}
```

### swift_demoApp.swift (Updated)
```swift
import SwiftUI
import FirebaseCore

@main
struct swift_demoApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    MainView()
                        .task {
                            // Perform crash recovery on app launch
                            await CrashRecoveryService.shared.performRecovery()
                            
                            // Process message queue
                            await MessageQueueService.shared.processQueue()
                        }
                } else {
                    LoginView()
                }
            }
            .environmentObject(authViewModel)
            .modelContainer(PersistenceController.shared.container)
        }
    }
}
```

### LocalStorageService.swift (Add Recovery Methods)
```swift
@MainActor
class LocalStorageService {
    // ... existing methods ...
    
    func findStaleMessages(olderThan date: Date, statuses: [MessageStatus]) throws -> [MessageEntity] {
        let statusStrings = statuses.map { $0.rawValue }
        
        let predicate = #Predicate<MessageEntity> { message in
            statusStrings.contains(message.statusRaw) &&
            message.timestamp < date
        }
        
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    func messageExists(messageId: String) throws -> Bool {
        let predicate = #Predicate<MessageEntity> { $0.id == messageId }
        let descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
        let results = try modelContext.fetch(descriptor)
        return !results.isEmpty
    }
}
```

## Acceptance Criteria
- [ ] Crash recovery runs on app launch
- [ ] Unsent messages detected automatically
- [ ] Unsent messages queued for retry
- [ ] No duplicate sends after recovery
- [ ] Messages that reached Firestore marked as delivered
- [ ] Messages that didn't reach Firestore get queued
- [ ] Recovery works in offline state
- [ ] Recovery logging provides visibility
- [ ] Multiple crashes don't cause issues
- [ ] No messages lost due to crashes

## Testing

### Test 1: Force Quit During Send
1. Open app and chat
2. Send message
3. Immediately force quit app (within 1 second)
4. Wait 5 seconds
5. Reopen app
6. Verify message is still there
7. Verify message sends successfully
8. Check recipient device - message arrives

### Test 2: Multiple Messages, Mid-Crash
1. Send 5 messages rapidly
2. Force quit during sends
3. Reopen app
4. Verify all 5 messages present
5. Verify all send successfully
6. No duplicates

### Test 3: Crash While Offline
1. Enable airplane mode
2. Send 3 messages
3. Force quit app
4. Reopen app (still offline)
5. Verify messages queued
6. Disable airplane mode
7. Verify messages send

### Test 4: Message Already Sent
1. Send message, wait for delivery
2. Manually set message status to "pending" in SwiftData
3. Restart app
4. Verify recovery detects it's already in Firestore
5. Verify local status updated to delivered
6. No duplicate message

## Notes
- Message IDs generated client-side are critical
- Idempotency prevents duplicates
- Check Firestore before re-sending
- SwiftData provides crash resilience for local storage
- Recovery should be fast (don't block app launch)
- Log recovery actions for debugging
- Consider edge case: message sent but conversation not updated
- Balance between false positives (re-sending sent messages) and false negatives (not recovering failed messages)
- 5-second threshold is heuristic - adjust based on testing

## Next PR
PR-13: Read Receipts (depends on PR-8)

