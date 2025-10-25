//
//  RetryPolicy.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

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
    
    static let conservative = RetryPolicy(
        maxRetries: 3,
        baseDelay: 2.0,
        maxDelay: 60.0,
        jitterFactor: 0.2
    )
    
    // For message queue: single attempt only (queue has its own retry logic)
    static let noRetry = RetryPolicy(
        maxRetries: 1,
        baseDelay: 0.0,
        maxDelay: 0.0,
        jitterFactor: 0.0
    )
    
    /// Calculate delay for a given retry attempt with exponential backoff and jitter
    func delay(forAttempt attempt: Int) -> TimeInterval {
        // Exponential backoff: baseDelay * 2^attempt
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
        let cappedDelay = min(exponentialDelay, maxDelay)
        
        // Add jitter: random variation to prevent thundering herd
        let jitter = cappedDelay * jitterFactor * Double.random(in: -1...1)
        
        return max(0, cappedDelay + jitter)
    }
    
    /// Determine if an error should be retried
    func shouldRetry(attempt: Int, error: Error) -> Bool {
        // Don't exceed max retries
        guard attempt < maxRetries else {
            print("❌ Max retries (\(maxRetries)) reached")
            return false
        }
        
        let nsError = error as NSError
        
        // Network errors: always retry
        if nsError.domain == NSURLErrorDomain {
            let retryableNetworkCodes = [
                NSURLErrorTimedOut,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorNotConnectedToInternet,
                NSURLErrorDNSLookupFailed
            ]
            
            if retryableNetworkCodes.contains(nsError.code) {
                print("🔄 Network error - will retry")
                return true
            }
        }
        
        // Firestore errors
        if nsError.domain == "FIRFirestoreErrorDomain" {
            // Retryable Firestore error codes:
            // 14: UNAVAILABLE - service unavailable
            // 4: DEADLINE_EXCEEDED - operation timeout
            // 13: INTERNAL - internal server error
            // 10: ABORTED - operation aborted (conflicting concurrent operations)
            let retryableFirestoreCodes = [14, 4, 13, 10]
            
            if retryableFirestoreCodes.contains(nsError.code) {
                print("🔄 Firestore error (\(nsError.code)) - will retry")
                return true
            }
            
            // Don't retry these:
            // 7: PERMISSION_DENIED
            // 16: UNAUTHENTICATED
            // 3: INVALID_ARGUMENT
            // 5: NOT_FOUND (unless document should exist)
            // 6: ALREADY_EXISTS
            let nonRetryableCodes = [7, 16, 3, 6]
            if nonRetryableCodes.contains(nsError.code) {
                print("⛔ Non-retryable Firestore error (\(nsError.code))")
                return false
            }
        }
        
        // Default: don't retry unknown errors
        print("⚠️ Unknown error domain: \(nsError.domain), code: \(nsError.code)")
        return false
    }
}

