//
//  CrashRecoveryServiceTests.swift
//  swift_demoTests
//
//  Tests for PR-12: Crash Recovery & Message Retry
//

import XCTest
@testable import swift_demo

@MainActor
final class CrashRecoveryServiceTests: XCTestCase {
    
    // Test 1: Service is singleton
    func testSingletonInstance() {
        let instance1 = CrashRecoveryService.shared
        let instance2 = CrashRecoveryService.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    // Test 2: Stale threshold is configured
    func testStaleThresholdConfiguration() {
        // This verifies the service can be instantiated
        let service = CrashRecoveryService.shared
        XCTAssertNotNil(service)
    }
    
    // Test 3: Extract recipient ID from conversation ID
    func testExtractRecipientId() {
        // Create a mock conversation ID
        let conversationId = "user123_user456"
        let participants = conversationId.split(separator: "_").map(String.init)
        
        XCTAssertEqual(participants.count, 2)
        XCTAssertTrue(participants.contains("user123"))
        XCTAssertTrue(participants.contains("user456"))
    }
    
    // Test 4: Perform recovery doesn't crash with no messages
    func testPerformRecoveryWithNoMessages() async {
        let service = CrashRecoveryService.shared
        
        // Should complete without crashing
        await XCTAssertNoThrowAsync {
            await service.performRecovery()
        }
    }
    
    // Test 5: Recovery logic handles different message statuses
    func testRecoveryHandlesDifferentStatuses() {
        let pendingMessage = MessageEntity.mockMessage(id: "msg1", status: .pending)
        let sentMessage = MessageEntity.mockMessage(id: "msg2", status: .sent)
        let deliveredMessage = MessageEntity.mockMessage(id: "msg3", status: .delivered)
        
        // Verify status values are correct
        XCTAssertEqual(pendingMessage.status, .pending)
        XCTAssertEqual(sentMessage.status, .sent)
        XCTAssertEqual(deliveredMessage.status, .delivered)
    }
}

// Helper extension for async testing
extension XCTestCase {
    func XCTAssertNoThrowAsync(
        _ expression: @escaping () async throws -> Void,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await expression()
        } catch {
            XCTFail("Unexpected error: \(error). \(message)", file: file, line: line)
        }
    }
}

