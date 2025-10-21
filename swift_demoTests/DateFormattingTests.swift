//
//  DateFormattingTests.swift
//  swift_demoTests
//
//  Tests for PR-14: Timestamps & Formatting
//

import XCTest
@testable import swift_demo

final class DateFormattingTests: XCTestCase {
    
    // Test 1: "Just now" for recent messages
    func testJustNowFormatting() {
        let now = Date()
        let thirtySecondsAgo = now.addingTimeInterval(-30)
        
        let formatted = thirtySecondsAgo.chatTimestamp()
        XCTAssertEqual(formatted, "Just now")
    }
    
    // Test 2: Minutes ago formatting
    func testMinutesAgoFormatting() {
        let now = Date()
        let fiveMinutesAgo = now.addingTimeInterval(-5 * 60)
        let thirtyMinutesAgo = now.addingTimeInterval(-30 * 60)
        
        XCTAssertEqual(fiveMinutesAgo.chatTimestamp(), "5m ago")
        XCTAssertEqual(thirtyMinutesAgo.chatTimestamp(), "30m ago")
    }
    
    // Test 3: Hours ago formatting for today
    func testHoursAgoFormatting() {
        let now = Date()
        let twoHoursAgo = now.addingTimeInterval(-2 * 60 * 60)
        
        let formatted = twoHoursAgo.chatTimestamp()
        XCTAssertTrue(formatted.contains("h ago") || formatted.contains("Yesterday"))
    }
    
    // Test 4: Yesterday formatting
    func testYesterdayFormatting() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let formatted = yesterday.chatTimestamp()
        
        XCTAssertTrue(formatted.contains("Yesterday"))
    }
    
    // Test 5: Conversation timestamp condensed format
    func testConversationTimestampFormat() {
        let now = Date()
        let recent = now.addingTimeInterval(-30)
        let fiveMinutes = now.addingTimeInterval(-5 * 60)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        
        XCTAssertEqual(recent.conversationTimestamp(), "now")
        XCTAssertEqual(fiveMinutes.conversationTimestamp(), "5m")
        XCTAssertEqual(yesterday.conversationTimestamp(), "Yesterday")
    }
    
    // Test 6: Same day comparison
    func testSameDayComparison() {
        let date1 = Date()
        let date2 = date1.addingTimeInterval(3600) // 1 hour later
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date1)!
        
        XCTAssertTrue(date1.isSameDay(as: date2))
        XCTAssertFalse(date1.isSameDay(as: yesterday))
    }
    
    // Test 7: Date separator text
    func testDateSeparatorText() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        XCTAssertEqual(today.dateSeparatorText(), "Today")
        XCTAssertEqual(yesterday.dateSeparatorText(), "Yesterday")
    }
}

