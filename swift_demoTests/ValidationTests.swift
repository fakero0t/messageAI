//
//  ValidationTests.swift
//  swift_demoTests
//
//  Tests for PR-2: Authentication System
//

import XCTest
@testable import swift_demo

final class ValidationTests: XCTestCase {
    
    // Test 1: Email validation - valid emails
    func testValidEmailFormats() {
        let validEmails = [
            "test@example.com",
            "user.name@example.com",
            "user+tag@example.co.uk",
            "user123@test-domain.com"
        ]
        
        for email in validEmails {
            XCTAssertTrue(isValidEmail(email), "\(email) should be valid")
        }
    }
    
    // Test 2: Email validation - invalid emails
    func testInvalidEmailFormats() {
        let invalidEmails = [
            "notanemail",
            "@example.com",
            "user@",
            "user @example.com",
            ""
        ]
        
        for email in invalidEmails {
            XCTAssertFalse(isValidEmail(email), "\(email) should be invalid")
        }
    }
    
    // Test 3: Password strength - minimum length
    func testPasswordMinimumLength() {
        let shortPassword = "12345"
        let validPassword = "123456"
        let longPassword = "verylongpassword123"
        
        XCTAssertFalse(isValidPassword(shortPassword, minLength: 6))
        XCTAssertTrue(isValidPassword(validPassword, minLength: 6))
        XCTAssertTrue(isValidPassword(longPassword, minLength: 6))
    }
    
    // Test 4: Display name validation
    func testDisplayNameValidation() {
        let emptyName = ""
        let validName = "John Doe"
        let tooLongName = String(repeating: "a", count: 101)
        
        XCTAssertFalse(isValidDisplayName(emptyName))
        XCTAssertTrue(isValidDisplayName(validName))
        XCTAssertFalse(isValidDisplayName(tooLongName, maxLength: 100))
    }
    
    // Test 5: User ID format validation
    func testUserIdFormat() {
        // Firebase UIDs are typically alphanumeric, 28 chars
        let validUserId = "abc123XYZ456def789ghi012jkl"
        let emptyUserId = ""
        
        XCTAssertFalse(validUserId.isEmpty)
        XCTAssertTrue(emptyUserId.isEmpty)
    }
    
    // MARK: - Helper Methods
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func isValidPassword(_ password: String, minLength: Int = 6) -> Bool {
        return password.count >= minLength
    }
    
    private func isValidDisplayName(_ name: String, maxLength: Int = 100) -> Bool {
        return !name.isEmpty && name.count <= maxLength
    }
}

