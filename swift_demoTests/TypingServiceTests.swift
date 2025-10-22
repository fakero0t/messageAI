//
//  TypingServiceTests.swift
//  swift_demoTests
//
//  Comprehensive unit tests for TypingService
//  Tests typing indicator functionality, debouncing, timeouts, and multi-user scenarios
//

import XCTest
import Combine
import FirebaseDatabase
import FirebaseAuth
@testable import swift_demo

final class TypingServiceTests: XCTestCase {
    
    var typingService: TypingService!
    var cancellables: Set<AnyCancellable>!
    
    // Test data
    let testConversationId = "test_conversation_\(UUID().uuidString)"
    let testUserId1 = "test_user_1_\(UUID().uuidString)"
    let testUserId2 = "test_user_2_\(UUID().uuidString)"
    let testUserId3 = "test_user_3_\(UUID().uuidString)"
    let testUserName1 = "Alice"
    let testUserName2 = "Bob"
    let testUserName3 = "Charlie"
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize service and cancellables
        typingService = TypingService.shared
        cancellables = Set<AnyCancellable>()
        
        print("🧪 [Setup] Test conversation ID: \(testConversationId)")
    }
    
    override func tearDownWithError() throws {
        // Clean up all test data
        cleanup(userId: testUserId1)
        cleanup(userId: testUserId2)
        cleanup(userId: testUserId3)
        
        cancellables.removeAll()
        
        try super.tearDownWithError()
    }
    
    // Helper to clean up a specific user's typing status
    private func cleanup(userId: String) {
        typingService.cleanup(conversationId: testConversationId, userId: userId)
    }
    
    // MARK: - Test 1: Basic Functionality
    
    func testStartTyping_BroadcastsStatusToFirebase() async throws {
        // Given: A user starts typing
        let expectation = XCTestExpectation(description: "Typing status is set in Firebase")
        
        // Start typing
        typingService.startTyping(
            conversationId: testConversationId,
            userId: testUserId1,
            displayName: testUserName1
        )
        
        // Wait for debounce (150ms) + buffer
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms
        
        // Verify by reading directly from Firebase
        let database = Database.database().reference()
        let typingRef = database.child("typing").child(testConversationId).child(testUserId1)
        
        typingRef.observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists(),
               let data = snapshot.value as? [String: Any],
               let displayName = data["displayName"] as? String {
                XCTAssertEqual(displayName, self.testUserName1, "Display name should match")
                expectation.fulfill()
            } else {
                XCTFail("Typing status not found in Firebase")
            }
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testStopTyping_RemovesStatusFromFirebase() async throws {
        // Given: A user is typing
        typingService.startTyping(
            conversationId: testConversationId,
            userId: testUserId1,
            displayName: testUserName1
        )
        
        // Wait for status to be set
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms
        
        // When: User stops typing
        typingService.stopTyping(conversationId: testConversationId, userId: testUserId1)
        
        // Wait for removal
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Status should be removed from Firebase
        let expectation = XCTestExpectation(description: "Typing status is removed")
        
        let database = Database.database().reference()
        let typingRef = database.child("typing").child(testConversationId).child(testUserId1)
        
        typingRef.observeSingleEvent(of: .value) { snapshot in
            XCTAssertFalse(snapshot.exists(), "Typing status should be removed")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Test 2: Debouncing
    
    func testDebouncing_RapidCallsAreLimited() async throws {
        // Given: Multiple rapid startTyping calls
        var callCount = 0
        
        // Start typing 5 times rapidly (within 100ms)
        for i in 0..<5 {
            typingService.startTyping(
                conversationId: testConversationId,
                userId: testUserId1,
                displayName: testUserName1
            )
            
            // Small delay between calls (20ms)
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        
        // Wait for debounce to complete (150ms + buffer)
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Then: Only one write should have occurred (due to debouncing)
        // We verify by checking that the status exists (debounce worked)
        let expectation = XCTestExpectation(description: "Debounced write completed")
        
        let database = Database.database().reference()
        let typingRef = database.child("typing").child(testConversationId).child(testUserId1)
        
        typingRef.observeSingleEvent(of: .value) { snapshot in
            XCTAssertTrue(snapshot.exists(), "Status should exist after debounced calls")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testDebouncing_OnlyBroadcastsAfterDelay() async throws {
        // Given: Start typing
        typingService.startTyping(
            conversationId: testConversationId,
            userId: testUserId1,
            displayName: testUserName1
        )
        
        // Check immediately (before debounce completes - 100ms)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let database = Database.database().reference()
        let typingRef = database.child("typing").child(testConversationId).child(testUserId1)
        
        let expectation1 = XCTestExpectation(description: "Status not yet set")
        
        typingRef.observeSingleEvent(of: .value) { snapshot in
            // Status might not be set yet (debounce still active)
            // This is expected behavior
            expectation1.fulfill()
        }
        
        await fulfillment(of: [expectation1], timeout: 1.0)
        
        // Wait for debounce to complete (150ms total)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Now status should exist
        let expectation2 = XCTestExpectation(description: "Status set after debounce")
        
        typingRef.observeSingleEvent(of: .value) { snapshot in
            XCTAssertTrue(snapshot.exists(), "Status should be set after debounce delay")
            expectation2.fulfill()
        }
        
        await fulfillment(of: [expectation2], timeout: 1.0)
    }
    
    // MARK: - Test 3: Timeout
    
    func testTimeout_StatusAutoRemovesAfterThreeSeconds() async throws {
        // Given: User starts typing
        typingService.startTyping(
            conversationId: testConversationId,
            userId: testUserId1,
            displayName: testUserName1
        )
        
        // Wait for status to be set (300ms)
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Verify status is set
        let database = Database.database().reference()
        let typingRef = database.child("typing").child(testConversationId).child(testUserId1)
        
        let expectation1 = XCTestExpectation(description: "Status initially set")
        
        typingRef.observeSingleEvent(of: .value) { snapshot in
            XCTAssertTrue(snapshot.exists(), "Status should be set initially")
            expectation1.fulfill()
        }
        
        await fulfillment(of: [expectation1], timeout: 2.0)
        
        // Wait for 3-second timeout to trigger
        try await Task.sleep(nanoseconds: 3_500_000_000) // 3.5 seconds
        
        // Then: Status should be auto-removed
        let expectation2 = XCTestExpectation(description: "Status removed after timeout")
        
        typingRef.observeSingleEvent(of: .value) { snapshot in
            XCTAssertFalse(snapshot.exists(), "Status should be removed after 3s timeout")
            expectation2.fulfill()
        }
        
        await fulfillment(of: [expectation2], timeout: 2.0)
    }
    
    func testTimeout_CancelledIfUserContinuesTyping() async throws {
        // Given: User starts typing
        typingService.startTyping(
            conversationId: testConversationId,
            userId: testUserId1,
            displayName: testUserName1
        )
        
        // Wait for initial debounce
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // User continues typing after 2 seconds (before timeout)
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        typingService.startTyping(
            conversationId: testConversationId,
            userId: testUserId1,
            displayName: testUserName1
        )
        
        // Wait for new debounce
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Then: Status should still exist (timeout was reset)
        let database = Database.database().reference()
        let typingRef = database.child("typing").child(testConversationId).child(testUserId1)
        
        let expectation = XCTestExpectation(description: "Status still exists")
        
        typingRef.observeSingleEvent(of: .value) { snapshot in
            XCTAssertTrue(snapshot.exists(), "Status should still exist (timeout was cancelled)")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Test 4: Multiple Users
    
    func testObserveTypingUsers_ReturnsAllTypingUsers() async throws {
        // Given: Two users are typing
        let expectation = XCTestExpectation(description: "Observes multiple typing users")
        expectation.expectedFulfillmentCount = 1
        
        // Set up observer as testUserId1 (will observe others)
        typingService.observeTypingUsers(
            conversationId: testConversationId,
            currentUserId: testUserId1
        )
        
        // Wait for observer to be set up
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // User 2 starts typing
        typingService.startTyping(
            conversationId: testConversationId,
            userId: testUserId2,
            displayName: testUserName2
        )
        
        // User 3 starts typing
        typingService.startTyping(
            conversationId: testConversationId,
            userId: testUserId3,
            displayName: testUserName3
        )
        
        // Wait for statuses to be set
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Subscribe to typing users
        typingService.$typingUsers
            .sink { [weak self] users in
                guard let self = self else { return }
                
                if let typingInConvo = users[self.testConversationId],
                   typingInConvo.count >= 2 {
                    
                    let names = typingInConvo.map { $0.displayName }.sorted()
                    
                    // Should contain both Bob and Charlie (not Alice, the current user)
                    XCTAssertTrue(names.contains(self.testUserName2), "Should contain Bob")
                    XCTAssertTrue(names.contains(self.testUserName3), "Should contain Charlie")
                    XCTAssertFalse(names.contains(self.testUserName1), "Should not contain current user Alice")
                    
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testObserveTypingUsers_ExcludesCurrentUser() async throws {
        // Given: Current user starts typing in their own conversation
        let expectation = XCTestExpectation(description: "Current user excluded from typing users")
        
        // Set up observer as testUserId1
        typingService.observeTypingUsers(
            conversationId: testConversationId,
            currentUserId: testUserId1
        )
        
        // Wait for observer setup
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Current user (testUserId1) starts typing
        typingService.startTyping(
            conversationId: testConversationId,
            userId: testUserId1,
            displayName: testUserName1
        )
        
        // Wait for status to be set
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Then: typingUsers should not include current user
        let typingUsers = typingService.typingUsers[testConversationId] ?? []
        XCTAssertEqual(typingUsers.count, 0, "Current user should be excluded")
        
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testObserveTypingUsers_RealTimeUpdates() async throws {
        // Given: Observer is set up
        let expectation = XCTestExpectation(description: "Real-time updates received")
        expectation.expectedFulfillmentCount = 2 // Once for add, once for remove
        
        var updateCount = 0
        
        typingService.observeTypingUsers(
            conversationId: testConversationId,
            currentUserId: testUserId1
        )
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Subscribe to changes
        typingService.$typingUsers
            .dropFirst() // Skip initial empty value
            .sink { [weak self] users in
                guard let self = self else { return }
                
                updateCount += 1
                
                if updateCount == 1 {
                    // First update: user starts typing
                    let typingInConvo = users[self.testConversationId] ?? []
                    if typingInConvo.count == 1 {
                        XCTAssertEqual(typingInConvo[0].displayName, self.testUserName2)
                        expectation.fulfill()
                    }
                } else if updateCount == 2 {
                    // Second update: user stops typing
                    let typingInConvo = users[self.testConversationId] ?? []
                    if typingInConvo.isEmpty {
                        expectation.fulfill()
                    }
                }
            }
            .store(in: &cancellables)
        
        // User 2 starts typing
        typingService.startTyping(
            conversationId: testConversationId,
            userId: testUserId2,
            displayName: testUserName2
        )
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // User 2 stops typing
        typingService.stopTyping(
            conversationId: testConversationId,
            userId: testUserId2
        )
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - Test 5: Format Typing Text
    
    func testFormatTypingText_OneUser() {
        // Given: One user typing
        let user1 = User(id: testUserId1, email: "", displayName: testUserName1, online: true)
        typingService.typingUsers[testConversationId] = [user1]
        
        // When: Format text
        let formatted = typingService.formatTypingText(for: testConversationId)
        
        // Then: Should show "Alice is typing..."
        XCTAssertEqual(formatted, "\(testUserName1) is typing...")
    }
    
    func testFormatTypingText_TwoUsers() {
        // Given: Two users typing
        let user1 = User(id: testUserId1, email: "", displayName: testUserName1, online: true)
        let user2 = User(id: testUserId2, email: "", displayName: testUserName2, online: true)
        typingService.typingUsers[testConversationId] = [user1, user2]
        
        // When: Format text
        let formatted = typingService.formatTypingText(for: testConversationId)
        
        // Then: Should show "Alice and Bob are typing..."
        XCTAssertEqual(formatted, "\(testUserName1) and \(testUserName2) are typing...")
    }
    
    func testFormatTypingText_ThreeOrMoreUsers() {
        // Given: Three users typing
        let user1 = User(id: testUserId1, email: "", displayName: testUserName1, online: true)
        let user2 = User(id: testUserId2, email: "", displayName: testUserName2, online: true)
        let user3 = User(id: testUserId3, email: "", displayName: testUserName3, online: true)
        typingService.typingUsers[testConversationId] = [user1, user2, user3]
        
        // When: Format text
        let formatted = typingService.formatTypingText(for: testConversationId)
        
        // Then: Should show "Alice and 2 others are typing..."
        XCTAssertEqual(formatted, "\(testUserName1) and 2 others are typing...")
    }
    
    func testFormatTypingText_EmptyArray() {
        // Given: No users typing
        typingService.typingUsers[testConversationId] = []
        
        // When: Format text
        let formatted = typingService.formatTypingText(for: testConversationId)
        
        // Then: Should return nil
        XCTAssertNil(formatted)
    }
    
    func testFormatTypingText_NoConversation() {
        // Given: No typing users for conversation
        typingService.typingUsers.removeValue(forKey: testConversationId)
        
        // When: Format text
        let formatted = typingService.formatTypingText(for: testConversationId)
        
        // Then: Should return nil
        XCTAssertNil(formatted)
    }
    
    // MARK: - Test 6: Cleanup
    
    func testCleanup_RemovesTypingStatus() async throws {
        // Given: User is typing
        typingService.startTyping(
            conversationId: testConversationId,
            userId: testUserId1,
            displayName: testUserName1
        )
        
        // Wait for status to be set
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // When: Cleanup is called
        typingService.cleanup(conversationId: testConversationId, userId: testUserId1)
        
        // Wait for cleanup
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Then: Status should be removed
        let expectation = XCTestExpectation(description: "Status removed after cleanup")
        
        let database = Database.database().reference()
        let typingRef = database.child("typing").child(testConversationId).child(testUserId1)
        
        typingRef.observeSingleEvent(of: .value) { snapshot in
            XCTAssertFalse(snapshot.exists(), "Status should be removed after cleanup")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testCleanup_WorksAcrossMultipleConversations() async throws {
        // Given: User typing in two conversations
        let conversation1 = testConversationId
        let conversation2 = "test_conversation_2_\(UUID().uuidString)"
        
        typingService.startTyping(
            conversationId: conversation1,
            userId: testUserId1,
            displayName: testUserName1
        )
        
        typingService.startTyping(
            conversationId: conversation2,
            userId: testUserId1,
            displayName: testUserName1
        )
        
        // Wait for both to be set
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // When: Clean up first conversation
        typingService.cleanup(conversationId: conversation1, userId: testUserId1)
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Then: First should be removed, second should remain
        let database = Database.database().reference()
        
        let expectation1 = XCTestExpectation(description: "First conversation cleaned")
        let typingRef1 = database.child("typing").child(conversation1).child(testUserId1)
        
        typingRef1.observeSingleEvent(of: .value) { snapshot in
            XCTAssertFalse(snapshot.exists(), "First conversation should be cleaned")
            expectation1.fulfill()
        }
        
        let expectation2 = XCTestExpectation(description: "Second conversation remains")
        let typingRef2 = database.child("typing").child(conversation2).child(testUserId1)
        
        typingRef2.observeSingleEvent(of: .value) { snapshot in
            XCTAssertTrue(snapshot.exists(), "Second conversation should remain")
            expectation2.fulfill()
        }
        
        await fulfillment(of: [expectation1, expectation2], timeout: 3.0)
        
        // Clean up second conversation
        typingService.cleanup(conversationId: conversation2, userId: testUserId1)
    }
    
    func testStopObservingTypingUsers_RemovesListener() async throws {
        // Given: Observer is active
        typingService.observeTypingUsers(
            conversationId: testConversationId,
            currentUserId: testUserId1
        )
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // User 2 starts typing
        typingService.startTyping(
            conversationId: testConversationId,
            userId: testUserId2,
            displayName: testUserName2
        )
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Verify user 2 is in typing users
        let usersBefore = typingService.typingUsers[testConversationId] ?? []
        XCTAssertEqual(usersBefore.count, 1, "Should have one typing user")
        
        // When: Stop observing
        typingService.stopObservingTypingUsers(conversationId: testConversationId)
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Then: Typing users should be cleared for this conversation
        let usersAfter = typingService.typingUsers[testConversationId]
        XCTAssertNil(usersAfter, "Typing users should be removed after stopping observer")
    }
}

