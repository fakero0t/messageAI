//
//  FirestoreRetryService.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import FirebaseFirestore

class FirestoreRetryService {
    static let shared = FirestoreRetryService()
    
    private init() {}
    
    /// Execute a Firestore operation with automatic retry logic
    func executeWithRetry<T>(
        policy: RetryPolicy = .default,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<policy.maxRetries {
            do {
                // Attempt the operation
                let result = try await operation()
                
                // Success!
                if attempt > 0 {
                    print("✅ Operation succeeded on attempt \(attempt + 1)")
                }
                return result
                
            } catch {
                lastError = error
                
                // Check if we should retry
                guard policy.shouldRetry(attempt: attempt, error: error) else {
                    print("🚫 Error not retryable: \(error.localizedDescription)")
                    throw error
                }
                
                // Calculate delay with exponential backoff
                let delay = policy.delay(forAttempt: attempt)
                print("⏳ Retry attempt \(attempt + 1)/\(policy.maxRetries) after \(String(format: "%.1f", delay))s")
                
                // Wait before retrying
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // All retries exhausted
        print("❌ All \(policy.maxRetries) retry attempts exhausted")
        throw lastError ?? NSError(
            domain: "FirestoreRetryService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Max retries exceeded"]
        )
    }
    
    /// Execute with retry and provide progress updates
    func executeWithRetry<T>(
        policy: RetryPolicy = .default,
        onRetry: @escaping (Int) -> Void,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<policy.maxRetries {
            do {
                let result = try await operation()
                if attempt > 0 {
                    print("✅ Operation succeeded on attempt \(attempt + 1)")
                }
                return result
                
            } catch {
                lastError = error
                
                guard policy.shouldRetry(attempt: attempt, error: error) else {
                    throw error
                }
                
                // Notify caller of retry
                onRetry(attempt + 1)
                
                let delay = policy.delay(forAttempt: attempt)
                print("⏳ Retry attempt \(attempt + 1)/\(policy.maxRetries) after \(String(format: "%.1f", delay))s")
                
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        print("❌ All \(policy.maxRetries) retry attempts exhausted")
        throw lastError ?? NSError(
            domain: "FirestoreRetryService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Max retries exceeded"]
        )
    }
}

