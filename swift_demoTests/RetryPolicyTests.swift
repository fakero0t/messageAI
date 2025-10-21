//
//  RetryPolicyTests.swift
//  swift_demoTests
//
//  Tests for PR-11: Network Monitoring & Resilience
//

import XCTest
@testable import swift_demo

final class RetryPolicyTests: XCTestCase {
    
    // Test 1: Default retry policy configuration
    func testDefaultRetryPolicyConfiguration() {
        let policy = RetryPolicy.default
        
        XCTAssertEqual(policy.maxRetries, 5)
        XCTAssertEqual(policy.baseDelay, 1.0)
        XCTAssertEqual(policy.maxDelay, 32.0)
        XCTAssertEqual(policy.jitterFactor, 0.1)
    }
    
    // Test 2: Exponential backoff calculation
    func testExponentialBackoffCalculation() {
        let policy = RetryPolicy.default
        
        // First attempt: ~1s
        let delay0 = policy.delay(forAttempt: 0)
        XCTAssertGreaterThanOrEqual(delay0, 0.9)
        XCTAssertLessThanOrEqual(delay0, 1.1)
        
        // Second attempt: ~2s
        let delay1 = policy.delay(forAttempt: 1)
        XCTAssertGreaterThanOrEqual(delay1, 1.8)
        XCTAssertLessThanOrEqual(delay1, 2.2)
        
        // Third attempt: ~4s
        let delay2 = policy.delay(forAttempt: 2)
        XCTAssertGreaterThanOrEqual(delay2, 3.6)
        XCTAssertLessThanOrEqual(delay2, 4.4)
    }
    
    // Test 3: Max delay cap
    func testMaxDelayCap() {
        let policy = RetryPolicy.default
        
        // Very high attempt should be capped at maxDelay
        let delay10 = policy.delay(forAttempt: 10)
        XCTAssertLessThanOrEqual(delay10, policy.maxDelay * 1.1) // Account for jitter
    }
    
    // Test 4: Retryable network errors
    func testRetryableNetworkErrors() {
        let policy = RetryPolicy.default
        
        let networkErrors = [
            NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut),
            NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost),
            NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost),
            NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        ]
        
        for error in networkErrors {
            XCTAssertTrue(
                policy.shouldRetry(attempt: 0, error: error),
                "Should retry network error code: \(error.code)"
            )
        }
    }
    
    // Test 5: Non-retryable Firestore errors
    func testNonRetryableFirestoreErrors() {
        let policy = RetryPolicy.default
        
        let nonRetryableErrors = [
            NSError(domain: "FIRFirestoreErrorDomain", code: 7),  // PERMISSION_DENIED
            NSError(domain: "FIRFirestoreErrorDomain", code: 16), // UNAUTHENTICATED
            NSError(domain: "FIRFirestoreErrorDomain", code: 3),  // INVALID_ARGUMENT
            NSError(domain: "FIRFirestoreErrorDomain", code: 6)   // ALREADY_EXISTS
        ]
        
        for error in nonRetryableErrors {
            XCTAssertFalse(
                policy.shouldRetry(attempt: 0, error: error),
                "Should not retry Firestore error code: \(error.code)"
            )
        }
    }
    
    // Test 6: Max retries enforcement
    func testMaxRetriesEnforcement() {
        let policy = RetryPolicy.default
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        
        // Should retry before max
        XCTAssertTrue(policy.shouldRetry(attempt: 4, error: error))
        
        // Should not retry at max
        XCTAssertFalse(policy.shouldRetry(attempt: 5, error: error))
        
        // Should not retry after max
        XCTAssertFalse(policy.shouldRetry(attempt: 6, error: error))
    }
}

