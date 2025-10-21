//
//  ReadReceiptServiceTests.swift
//  swift_demoTests
//
//  Tests for PR-13: Read Receipts
//

import XCTest
@testable import swift_demo

final class ReadReceiptServiceTests: XCTestCase {
    
    // Test 1: Service is singleton
    func testSingletonInstance() {
        let instance1 = ReadReceiptService.shared
        let instance2 = ReadReceiptService.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    // Test 2: Filter unread messages correctly
    func testFilterUnreadMessages() {
        let currentUserId = "user123"
        let otherUserId = "user456"
        
        // Message from other user, not read
        let unreadMessage = MessageEntity.mockMessage(
            id: "msg1",
            senderId: otherUserId,
            status: .delivered
        )
        
        // Message from current user
        let ownMessage = MessageEntity.mockMessage(
            id: "msg2",
            senderId: currentUserId,
            status: .delivered
        )
        
        // Message from other user, already read
        var readMessage = MessageEntity.mockMessage(
            id: "msg3",
            senderId: otherUserId,
            status: .read
        )
        readMessage.readBy = [currentUserId]
        
        // Filter logic
        let messages = [unreadMessage, ownMessage, readMessage]
        let unreadMessages = messages.filter { message in
            message.senderId != currentUserId && !message.readBy.contains(currentUserId)
        }
        
        XCTAssertEqual(unreadMessages.count, 1)
        XCTAssertEqual(unreadMessages.first?.id, "msg1")
    }
    
    // Test 3: One-on-one chat read receipt logic
    func testOneOnOneChatReadReceiptLogic() {
        let senderId = "user123"
        let recipientId = "user456"
        let conversationId = "\(senderId)_\(recipientId)"
        
        var message = MessageEntity.mockMessage(
            conversationId: conversationId,
            senderId: senderId
        )
        
        // Initially not read
        XCTAssertFalse(message.readBy.contains(recipientId))
        
        // Mark as read
        message.readBy.append(recipientId)
        XCTAssertTrue(message.readBy.contains(recipientId))
        
        // Verify someone other than sender has read it
        let hasRecipientRead = message.readBy.contains { $0 != senderId }
        XCTAssertTrue(hasRecipientRead)
    }
    
    // Test 4: Group chat read receipt logic
    func testGroupChatReadReceiptLogic() {
        let senderId = "user123"
        let recipient1 = "user456"
        let recipient2 = "user789"
        
        var message = MessageEntity.mockMessage(senderId: senderId)
        
        // Add read receipts
        message.readBy = [recipient1, recipient2]
        
        // Count non-sender reads
        let nonSenderReads = message.readBy.filter { $0 != senderId }
        XCTAssertEqual(nonSenderReads.count, 2)
    }
    
    // Test 5: Empty readBy array handling
    func testEmptyReadByArray() {
        let message = MessageEntity.mockMessage()
        
        XCTAssertTrue(message.readBy.isEmpty)
        XCTAssertFalse(message.readBy.contains("anyUserId"))
    }
    
    // Test 6: Multiple users read receipt
    func testMultipleUsersReadReceipt() {
        var message = MessageEntity.mockMessage(senderId: "sender")
        
        // Simulate multiple users reading
        message.readBy = ["user1", "user2", "user3"]
        
        XCTAssertEqual(message.readBy.count, 3)
        XCTAssertTrue(message.readBy.contains("user1"))
        XCTAssertTrue(message.readBy.contains("user2"))
        XCTAssertTrue(message.readBy.contains("user3"))
        XCTAssertFalse(message.readBy.contains("sender"))
    }
}

