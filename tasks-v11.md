# PR-11: Network Monitoring & Resilience

## Overview
Enhance network resilience with proper retry logic, exponential backoff, and graceful handling of poor network conditions (3G, packet loss, intermittent connectivity).

## Dependencies
- PR-10: Offline Message Queueing

## Tasks

### 1. Implement Exponential Backoff
- [ ] Create `Services/RetryPolicy.swift`
  - [ ] Exponential backoff algorithm
  - [ ] Configurable retry delays (1s, 2s, 4s, 8s, 16s)
  - [ ] Max retry attempts
  - [ ] Jitter to prevent thundering herd
  - [ ] Backoff reset on success

### 2. Enhance Network Monitor
- [ ] Update `Services/NetworkMonitor.swift`
  - [ ] Detect connection quality
  - [ ] Monitor for WiFi vs Cellular
  - [ ] Detect bandwidth limitations
  - [ ] Publish connection quality updates

### 3. Implement Retry Logic for Firestore
- [ ] Create `Services/FirestoreRetryService.swift`
  - [ ] Wrap Firestore operations with retry
  - [ ] Apply exponential backoff
  - [ ] Handle specific error types differently
  - [ ] Network errors: retry
  - [ ] Auth errors: don't retry
  - [ ] Rate limit errors: back off longer

### 4. Handle Poor Network Gracefully
- [ ] Increase timeouts for 3G/poor connections
- [ ] Show user-friendly messages
- [ ] Continue accepting new messages
- [ ] Queue operations during poor connectivity
- [ ] Don't block UI on slow network

### 5. Add Connection Status Indicator
- [ ] Update `NetworkStatusView.swift`
  - [ ] Show connection strength
  - [ ] Indicate poor connection
  - [ ] Show retry in progress
  - [ ] Provide helpful guidance

### 6. Implement Request Queuing
- [ ] Queue Firestore operations during poor network
- [ ] Process queue with backoff
- [ ] Prioritize recent operations
- [ ] Cancel stale operations

### 7. Add Timeout Handling
- [ ] Set appropriate timeouts for operations
- [ ] Longer timeouts for poor connections
- [ ] Cancel operations that timeout
- [ ] Retry timed-out operations

### 8. Monitor Network State Changes
- [ ] Track transitions: WiFi ↔ Cellular ↔ Offline
- [ ] Adjust retry strategy based on connection type
- [ ] Re-establish listeners on network change
- [ ] Clear stale connections

## Files to Create/Modify

### New Files
- `swift_demo/Services/RetryPolicy.swift`
- `swift_demo/Services/FirestoreRetryService.swift`

### Modified Files
- `swift_demo/Services/NetworkMonitor.swift` - Enhanced monitoring
- `swift_demo/Services/MessageService.swift` - Add retry wrapper
- `swift_demo/Services/MessageQueueService.swift` - Use retry policy
- `swift_demo/Views/Components/NetworkStatusView.swift` - Better UX

## Code Structure Examples

### RetryPolicy.swift
```swift
import Foundation

struct RetryPolicy {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let jitterFactor: Double
    
    static let `default` = RetryPolicy(
        maxRetries: 5,
        baseDelay: 1.0,
        maxDelay: 32.0,
        jitterFactor: 0.1
    )
    
    static let aggressive = RetryPolicy(
        maxRetries: 10,
        baseDelay: 0.5,
        maxDelay: 16.0,
        jitterFactor: 0.1
    )
    
    func delay(forAttempt attempt: Int) -> TimeInterval {
        // Exponential backoff: baseDelay * 2^attempt
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
        let cappedDelay = min(exponentialDelay, maxDelay)
        
        // Add jitter: ±10% random variation
        let jitter = cappedDelay * jitterFactor * (Double.random(in: -1...1))
        
        return max(0, cappedDelay + jitter)
    }
    
    func shouldRetry(attempt: Int, error: Error) -> Bool {
        guard attempt < maxRetries else { return false }
        
        // Check if error is retryable
        if let nsError = error as NSError? {
            // Network errors: retry
            if nsError.domain == NSURLErrorDomain {
                return true
            }
            
            // Firestore errors
            if nsError.domain == "FIRFirestoreErrorDomain" {
                // Unavailable, deadline exceeded, etc: retry
                let retryableCodes = [14, 4, 13] // UNAVAILABLE, DEADLINE_EXCEEDED, INTERNAL
                return retryableCodes.contains(nsError.code)
            }
        }
        
        return false
    }
}
```

### FirestoreRetryService.swift
```swift
import Foundation
import FirebaseFirestore

class FirestoreRetryService {
    static let shared = FirestoreRetryService()
    
    func executeWithRetry<T>(
        policy: RetryPolicy = .default,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<policy.maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Check if we should retry
                guard policy.shouldRetry(attempt: attempt, error: error) else {
                    throw error
                }
                
                // Wait with exponential backoff
                let delay = policy.delay(forAttempt: attempt)
                print("Retry attempt \(attempt + 1) after \(delay)s delay")
                
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // All retries exhausted
        throw lastError ?? NSError(
            domain: "FirestoreRetryService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Max retries exceeded"]
        )
    }
}
```

### NetworkMonitor.swift (Enhanced)
```swift
import Foundation
import Network
import Combine

enum ConnectionQuality {
    case excellent  // WiFi with good signal
    case good       // WiFi or 5G/LTE
    case fair       // 4G or weak WiFi
    case poor       // 3G or very weak connection
    case offline    // No connection
}

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType?
    @Published var connectionQuality: ConnectionQuality = .excellent
    
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
                self?.updateConnectionQuality(path: path)
                
                if path.status == .satisfied {
                    NotificationCenter.default.post(name: .networkRestored, object: nil)
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func updateConnectionQuality(path: NWPath) {
        if path.status != .satisfied {
            connectionQuality = .offline
            return
        }
        
        // Heuristic based on connection type
        if path.usesInterfaceType(.wifi) {
            connectionQuality = path.isExpensive ? .good : .excellent
        } else if path.usesInterfaceType(.cellular) {
            // Rough heuristic - could be improved with actual bandwidth tests
            connectionQuality = path.isConstrained ? .poor : .fair
        } else {
            connectionQuality = .good
        }
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
}

extension Notification.Name {
    static let networkRestored = Notification.Name("networkRestored")
}
```

### MessageService.swift (Updated with Retry)
```swift
import Foundation
import FirebaseFirestore

class MessageService {
    static let shared = MessageService()
    private let db = Firestore.firestore()
    private let localStorage = LocalStorageService.shared
    private let retryService = FirestoreRetryService.shared
    
    func sendToFirestore(
        messageId: String,
        text: String,
        conversationId: String,
        senderId: String,
        recipientId: String
    ) async throws {
        // Wrap in retry logic
        try await retryService.executeWithRetry(policy: .default) {
            let messageData: [String: Any] = [
                "id": messageId,
                "conversationId": conversationId,
                "senderId": senderId,
                "text": text,
                "timestamp": FieldValue.serverTimestamp(),
                "status": "delivered",
                "readBy": [senderId]
            ]
            
            try await self.db.collection("messages").document(messageId).setData(messageData)
            
            // Update conversation
            try await ConversationService.shared.updateConversation(
                conversationId: conversationId,
                lastMessage: text,
                participants: [senderId, recipientId]
            )
        }
    }
    
    // ... other methods ...
}
```

### NetworkStatusView.swift (Enhanced)
```swift
import SwiftUI

struct NetworkStatusView: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @ObservedObject var queueService = MessageQueueService.shared
    
    var body: some View {
        if shouldShow {
            HStack(spacing: 8) {
                statusIcon
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if queueService.isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .cornerRadius(16)
        }
    }
    
    private var shouldShow: Bool {
        !networkMonitor.isConnected ||
        networkMonitor.connectionQuality == .poor ||
        queueService.queueCount > 0
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch networkMonitor.connectionQuality {
        case .offline:
            Image(systemName: "wifi.slash")
                .foregroundColor(.red)
        case .poor:
            Image(systemName: "wifi.exclamationmark")
                .foregroundColor(.orange)
        case .fair:
            Image(systemName: "wifi")
                .foregroundColor(.yellow)
        default:
            if queueService.queueCount > 0 {
                Image(systemName: "arrow.up.circle")
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var statusText: String {
        if !networkMonitor.isConnected {
            return "Offline - Messages will send when connected"
        } else if networkMonitor.connectionQuality == .poor {
            return "Poor connection - Messages may be delayed"
        } else if queueService.queueCount > 0 {
            return "Sending \(queueService.queueCount) message(s)..."
        }
        return ""
    }
    
    private var backgroundColor: Color {
        switch networkMonitor.connectionQuality {
        case .offline:
            return Color.red.opacity(0.1)
        case .poor:
            return Color.orange.opacity(0.1)
        default:
            return Color(.systemGray6)
        }
    }
}
```

## Acceptance Criteria
- [ ] Retry logic with exponential backoff implemented
- [ ] Network quality detected and displayed
- [ ] Poor connections handled gracefully
- [ ] Operations retry automatically on failure
- [ ] Max retry limit respected
- [ ] User sees clear connection status
- [ ] Messages queue on poor connection
- [ ] No UI blocking on slow network
- [ ] Timeouts handled appropriately
- [ ] Network transitions handled smoothly
- [ ] 3G connections work reliably

## Testing
1. Enable Network Link Conditioner on Mac
2. Set to "3G" profile
3. Send messages
4. Verify they eventually send with retries
5. Set to "Very Bad Network" profile
6. Send messages
7. Verify queue builds up
8. Restore to "WiFi" profile
9. Verify queue processes
10. Test rapid network switching
11. Verify no crashes or lost messages
12. Test 100% packet loss
13. Verify offline mode activates

## Notes
- Exponential backoff prevents server overload
- Jitter prevents thundering herd problem
- Different errors need different retry strategies
- Network quality impacts user expectations
- Clear status indicators reduce user frustration
- Don't retry non-retryable errors (auth, permission)
- Balance between aggressive retries and battery/data usage

## Next PR
PR-12: Crash Recovery & Message Retry (depends on this PR)

