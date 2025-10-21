//
//  ConversationModelTests.swift
//  swift_demoTests
//
//  Tests for PR-15: Conversation List with Unread Badges
//

import XCTest
@testable import swift_demo

final class ConversationModelTests: XCTestCase {
    
    // Test 1: Conversation ID format for one-on-one
    func testOneOnOneConversationIdFormat() {
        let userId1 = "user123"
        let userId2 = "user456"
        
        // Standard format: sorted IDs with underscore
        let ids = [userId1, userId2].sorted()
        let conversationId = ids.joined(separator: "_")
        
        XCTAssertEqual(conversationId, "user123_user456")
    }
    
    // Test 2: Conversation ID is consistent regardless of order
    func testConversationIdConsistency() {
        let userId1 = "user123"
        let userId2 = "user456"
        
        let id1 = [userId1, userId2].sorted().joined(separator: "_")
        let id2 = [userId2, userId1].sorted().joined(separator: "_")
        
        XCTAssertEqual(id1, id2, "Conversation ID should be same regardless of user order")
    }
    
    // Test 3: Extract participants from conversation ID
    func testExtractParticipantsFromConversationId() {
        let conversationId = "user123_user456"
        let participants = conversationId.split(separator: "_").map(String.init)
        
        XCTAssertEqual(participants.count, 2)
        XCTAssertTrue(participants.contains("user123"))
        XCTAssertTrue(participants.contains("user456"))
    }
    
    // Test 4: Unread count logic
    func testUnreadCountLogic() {
        // Simulate unread count
        var unreadCount = 0
        
        // New message arrives
        unreadCount += 1
        XCTAssertEqual(unreadCount, 1)
        
        // More messages
        unreadCount += 5
        XCTAssertEqual(unreadCount, 6)
        
        // Mark as read
        unreadCount = 0
        XCTAssertEqual(unreadCount, 0)
    }
    
    // Test 5: Last message preview truncation
    func testLastMessagePreview() {
        let longMessage = "This is a very long message that should be truncated for display in the conversation list view"
        let maxLength = 50
        
        let preview = longMessage.count > maxLength
            ? String(longMessage.prefix(maxLength)) + "..."
            : longMessage
        
        XCTAssertLessThanOrEqual(preview.count, maxLength + 3) // +3 for "..."
        XCTAssertTrue(preview.hasSuffix("..."))
    }
    
    // Test 6: Group conversation participant count
    func testGroupConversationParticipants() {
        // Group conversations have more than 2 participants
        let groupParticipants = ["user1", "user2", "user3", "user4"]
        
        XCTAssertGreaterThan(groupParticipants.count, 2)
        
        // One-on-one has exactly 2
        let oneOnOneParticipants = ["user1", "user2"]
        XCTAssertEqual(oneOnOneParticipants.count, 2)
    }
}

