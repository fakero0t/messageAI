//
//  UserModelTests.swift
//  swift_demoTests
//
//  Tests for PR-5: User Profile & Online Status
//

import XCTest
@testable import swift_demo

final class UserModelTests: XCTestCase {
    
    // Test 1: User initialization with all fields
    func testUserInitialization() {
        let user = User(
            id: "user123",
            email: "test@example.com",
            username: "testuser",
            displayName: "Test User",
            online: true,
            lastSeen: Date()
        )
        
        XCTAssertEqual(user.id, "user123")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.username, "testuser")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertTrue(user.online)
        XCTAssertNotNil(user.lastSeen)
    }
    
    // Test 2: User initialization with nil lastSeen
    func testUserInitializationWithNilLastSeen() {
        let user = User(
            id: "user456",
            email: "test2@example.com",
            username: "testuser2",
            displayName: "Test User 2",
            online: false,
            lastSeen: nil
        )
        
        XCTAssertEqual(user.id, "user456")
        XCTAssertEqual(user.username, "testuser2")
        XCTAssertFalse(user.online)
        XCTAssertNil(user.lastSeen)
    }
    
    // Test 3: Mock user helper
    func testMockUserHelper() {
        let mockUser = User.mockUser()
        
        XCTAssertEqual(mockUser.id, "user123")
        XCTAssertEqual(mockUser.email, "test@example.com")
        XCTAssertEqual(mockUser.displayName, "Test User")
        XCTAssertTrue(mockUser.online)
    }
    
    // Test 4: Custom mock user
    func testCustomMockUser() {
        let customUser = User.mockUser(
            id: "custom999",
            email: "custom@example.com"
        )
        
        XCTAssertEqual(customUser.id, "custom999")
        XCTAssertEqual(customUser.email, "custom@example.com")
    }
    
    // Test 5: Online status logic
    func testOnlineStatusLogic() {
        let onlineUser = User.mockUser()
        let offlineUser = User(
            id: "offline",
            email: "offline@example.com",
            username: "offlineuser",
            displayName: "Offline User",
            online: false,
            lastSeen: Date()
        )
        
        XCTAssertTrue(onlineUser.online)
        XCTAssertFalse(offlineUser.online)
        XCTAssertNotNil(offlineUser.lastSeen)
    }
}

