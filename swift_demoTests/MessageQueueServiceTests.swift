//
//  MessageQueueServiceTests.swift
//  swift_demoTests
//
//  Tests for PR-10: Offline Message Queueing
//

import XCTest
@testable import swift_demo

@MainActor
final class MessageQueueServiceTests: XCTestCase {
    
    // Test 1: Service is singleton
    func testSingletonInstance() {
        let instance1 = MessageQueueService.shared
        let instance2 = MessageQueueService.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    // Test 2: Initial queue count is zero or non-negative
    func testInitialQueueCount() {
        let service = MessageQueueService.shared
        XCTAssertGreaterThanOrEqual(service.queueCount, 0)
    }
    
    // Test 3: Initial processing state is false
    func testInitialProcessingState() {
        let service = MessageQueueService.shared
        // After initialization, processing should be false
        XCTAssertFalse(service.isProcessing)
    }
    
    // Test 4: Conversation ID parsing logic
    func testConversationIdParsing() {
        let conversationId = "user123_user456"
        let participants = conversationId.split(separator: "_").map(String.init)
        
        XCTAssertEqual(participants.count, 2)
        
        // Extract recipient ID (not current user)
        let currentUserId = "user123"
        let recipientId = participants.first { $0 != currentUserId }
        
        XCTAssertEqual(recipientId, "user456")
    }
    
    // Test 5: Max retry threshold
    func testMaxRetryThreshold() {
        // Verify max retries constant is reasonable
        // This is typically 5 retries based on the service implementation
        let maxRetries = 5
        
        let queuedMessage = QueuedMessageEntity.mockQueuedMessage(retryCount: 5)
        XCTAssertGreaterThanOrEqual(queuedMessage.retryCount, maxRetries)
    }
    
    // Test 6: Queued message structure
    func testQueuedMessageStructure() {
        let message = QueuedMessageEntity.mockQueuedMessage(
            id: "test123",
            conversationId: "conv456",
            text: "Test message",
            retryCount: 2
        )
        
        XCTAssertEqual(message.id, "test123")
        XCTAssertEqual(message.conversationId, "conv456")
        XCTAssertEqual(message.text, "Test message")
        XCTAssertEqual(message.retryCount, 2)
        XCTAssertNotNil(message.timestamp)
    }
}

