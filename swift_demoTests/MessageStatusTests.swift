//
//  MessageStatusTests.swift
//  swift_demoTests
//
//  Tests for PR-9: Optimistic UI & Message Status
//

import XCTest
@testable import swift_demo

final class MessageStatusTests: XCTestCase {
    
    // Test 1: Status raw values
    func testStatusRawValues() {
        XCTAssertEqual(MessageStatus.pending.rawValue, "pending")
        XCTAssertEqual(MessageStatus.sent.rawValue, "sent")
        XCTAssertEqual(MessageStatus.queued.rawValue, "queued")
        XCTAssertEqual(MessageStatus.delivered.rawValue, "delivered")
        XCTAssertEqual(MessageStatus.read.rawValue, "read")
        XCTAssertEqual(MessageStatus.failed.rawValue, "failed")
    }
    
    // Test 2: Display text formatting
    func testDisplayTextFormatting() {
        XCTAssertEqual(MessageStatus.pending.displayText, "Sending...")
        XCTAssertEqual(MessageStatus.sent.displayText, "Sent")
        XCTAssertEqual(MessageStatus.queued.displayText, "Queued")
        XCTAssertEqual(MessageStatus.delivered.displayText, "Delivered")
        XCTAssertEqual(MessageStatus.read.displayText, "Read")
        XCTAssertEqual(MessageStatus.failed.displayText, "Failed")
    }
    
    // Test 3: Icon names
    func testIconNames() {
        XCTAssertEqual(MessageStatus.pending.iconName, "clock")
        XCTAssertEqual(MessageStatus.sent.iconName, "checkmark")
        XCTAssertEqual(MessageStatus.queued.iconName, "clock.arrow.circlepath")
        XCTAssertEqual(MessageStatus.delivered.iconName, "checkmark.circle")
        XCTAssertEqual(MessageStatus.read.iconName, "checkmark.circle.fill")
        XCTAssertEqual(MessageStatus.failed.iconName, "exclamationmark.circle")
    }
    
    // Test 4: Codable encoding
    func testEncodingStatus() throws {
        let status = MessageStatus.delivered
        let encoder = JSONEncoder()
        let data = try encoder.encode(status)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "\"delivered\"")
    }
    
    // Test 5: Codable decoding
    func testDecodingStatus() throws {
        let jsonString = "\"read\""
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let status = try decoder.decode(MessageStatus.self, from: data)
        
        XCTAssertEqual(status, .read)
    }
    
    // Test 6: Status progression logic
    func testStatusProgression() {
        // Test logical progression: pending -> sent -> delivered -> read
        let statuses: [MessageStatus] = [.pending, .sent, .delivered, .read]
        
        // Verify they're all unique
        let uniqueStatuses = Set(statuses.map { $0.rawValue })
        XCTAssertEqual(uniqueStatuses.count, 4)
        
        // Verify failed is separate from progression
        XCTAssertNotEqual(MessageStatus.failed, .delivered)
        XCTAssertNotEqual(MessageStatus.queued, .sent)
    }
}

