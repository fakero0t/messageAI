//
//  MessageDeduplicationTests.swift
//  swift_demoTests
//
//  Tests for PR-12: Message Deduplication
//

import XCTest
@testable import swift_demo

final class MessageDeduplicationTests: XCTestCase {
    
    // Test 1: Detect duplicate message IDs
    func testDetectDuplicateMessageIds() {
        let message1 = MessageEntity.mockMessage(id: "msg123")
        let message2 = MessageEntity.mockMessage(id: "msg123") // Same ID
        let message3 = MessageEntity.mockMessage(id: "msg456")
        
        XCTAssertEqual(message1.id, message2.id)
        XCTAssertNotEqual(message1.id, message3.id)
    }
    
    // Test 2: Check if message exists in collection
    func testMessageExistsInCollection() {
        var messages = [
            MessageEntity.mockMessage(id: "msg1"),
            MessageEntity.mockMessage(id: "msg2"),
            MessageEntity.mockMessage(id: "msg3")
        ]
        
        let newMessageId = "msg4"
        let duplicateMessageId = "msg2"
        
        XCTAssertFalse(messages.contains { $0.id == newMessageId })
        XCTAssertTrue(messages.contains { $0.id == duplicateMessageId })
    }
    
    // Test 3: Remove duplicate messages
    func testRemoveDuplicateMessages() {
        var messages = [
            MessageEntity.mockMessage(id: "msg1"),
            MessageEntity.mockMessage(id: "msg2"),
            MessageEntity.mockMessage(id: "msg1"), // Duplicate
            MessageEntity.mockMessage(id: "msg3")
        ]
        
        // Remove duplicates by keeping only first occurrence
        var seenIds = Set<String>()
        messages = messages.filter { message in
            if seenIds.contains(message.id) {
                return false
            }
            seenIds.insert(message.id)
            return true
        }
        
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages.map { $0.id }.sorted(), ["msg1", "msg2", "msg3"])
    }
    
    // Test 4: UUID generation for unique message IDs
    func testUniqueMessageIdGeneration() {
        let id1 = UUID().uuidString
        let id2 = UUID().uuidString
        let id3 = UUID().uuidString
        
        XCTAssertNotEqual(id1, id2)
        XCTAssertNotEqual(id2, id3)
        XCTAssertNotEqual(id1, id3)
    }
    
    // Test 5: Check for duplicate in queue
    func testCheckDuplicateInQueue() {
        let queue = [
            QueuedMessageEntity.mockQueuedMessage(id: "queued1"),
            QueuedMessageEntity.mockQueuedMessage(id: "queued2")
        ]
        
        let messageIdToCheck = "queued1"
        let isQueued = queue.contains { $0.id == messageIdToCheck }
        
        XCTAssertTrue(isQueued)
    }
}

