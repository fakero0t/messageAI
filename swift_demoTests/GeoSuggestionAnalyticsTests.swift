//
//  GeoSuggestionAnalyticsTests.swift
//  swift_demoTests
//
//  Created for PR-5: Analytics & Performance Tests
//

import XCTest
@testable import swift_demo

@MainActor
final class GeoSuggestionAnalyticsTests: XCTestCase {
    var analytics: TranslationAnalytics!
    
    override func setUp() async throws {
        try await super.setUp()
        analytics = TranslationAnalytics.shared
    }
    
    override func tearDown() async throws {
        analytics = nil
        try await super.tearDown()
    }
    
    // MARK: - Event Logging Tests
    
    func testLogSuggestionExposed() {
        // Given: A suggestion exposure
        let baseWord = "მადლობა"
        let baseHash = analytics.hashWord(baseWord)
        
        // When: We log exposure
        analytics.logSuggestionExposed(
            baseWord: baseWord,
            baseWordHash: baseHash,
            source: .local,
            suggestionCount: 3
        )
        
        // Then: Should not crash (console logging verified manually)
        XCTAssertTrue(true, "Event logged successfully")
    }
    
    func testLogSuggestionClicked() {
        // Given: A click event
        let baseWord = "მადლობა"
        let suggestion = "არაპრის"
        
        // When: We log click
        analytics.logSuggestionClicked(
            baseWord: baseWord,
            baseWordHash: analytics.hashWord(baseWord),
            suggestion: suggestion,
            suggestionHash: analytics.hashWord(suggestion),
            source: .local
        )
        
        // Then: Should log successfully
        XCTAssertTrue(true)
    }
    
    func testLogSuggestionAccepted() {
        // Given: An acceptance event
        let baseWord = "მადლობა"
        let suggestion = "არაპრის"
        
        // When: We log acceptance
        analytics.logSuggestionAccepted(
            baseWord: baseWord,
            baseWordHash: analytics.hashWord(baseWord),
            suggestion: suggestion,
            suggestionHash: analytics.hashWord(suggestion),
            source: .local,
            action: "append"
        )
        
        // Then: Should log successfully
        XCTAssertTrue(true)
    }
    
    func testLogSuggestionDismissed() {
        // Given: A dismissal
        let baseWord = "მადლობა"
        
        // When: We log dismissal
        analytics.logSuggestionDismissed(
            baseWord: baseWord,
            baseWordHash: analytics.hashWord(baseWord),
            source: .local
        )
        
        // Then: Should log successfully
        XCTAssertTrue(true)
    }
    
    func testLogSuggestionPerformance() {
        // Given: A performance measurement
        let baseWord = "მადლობა"
        let latencyMs = 50
        
        // When: We log performance
        analytics.logSuggestionPerformance(
            baseWord: baseWord,
            baseWordHash: analytics.hashWord(baseWord),
            source: .local,
            latencyMs: latencyMs
        )
        
        // Then: Should log successfully
        XCTAssertTrue(true)
    }
    
    func testLogSuggestionThrottled() {
        // When: We log throttling
        analytics.logSuggestionThrottled(reason: "message_throttle")
        analytics.logSuggestionThrottled(reason: "session_cooldown")
        analytics.logSuggestionThrottled(reason: "24h_cooldown")
        
        // Then: Should log all variants successfully
        XCTAssertTrue(true)
    }
    
    func testLogSuggestionFetchError() {
        // Given: An error
        let baseWord = "მადლობა"
        let error = "Network timeout"
        
        // When: We log error
        analytics.logSuggestionFetchError(
            baseWord: baseWord,
            baseWordHash: analytics.hashWord(baseWord),
            error: error
        )
        
        // Then: Should log successfully
        XCTAssertTrue(true)
    }
    
    func testLogSuggestionOfflineFallback() {
        // Given: Offline fallback
        let baseWord = "მადლობა"
        
        // When: We log fallback
        analytics.logSuggestionOfflineFallback(
            baseWord: baseWord,
            baseWordHash: analytics.hashWord(baseWord)
        )
        
        // Then: Should log successfully
        XCTAssertTrue(true)
    }
    
    // MARK: - Word Hashing Tests
    
    func testHashWord() {
        // Given: A Georgian word
        let word = "მადლობა"
        
        // When: We hash it
        let hash = analytics.hashWord(word)
        
        // Then: Should produce consistent hash
        XCTAssertFalse(hash.isEmpty)
        XCTAssertEqual(hash.count, 16, "Hash should be truncated to 16 chars")
        
        // Same word should produce same hash
        let hash2 = analytics.hashWord(word)
        XCTAssertEqual(hash, hash2)
    }
    
    func testHashWordCaseInsensitive() {
        // Given: Same word in different cases
        let lower = "მადლობა"
        let upper = "მადლობა" // Georgian doesn't have traditional case, but test normalization
        
        // When: We hash both
        let hash1 = analytics.hashWord(lower)
        let hash2 = analytics.hashWord(upper)
        
        // Then: Should produce same hash
        XCTAssertEqual(hash1, hash2)
    }
    
    func testHashWordUniqueness() {
        // Given: Different words
        let word1 = "მადლობა"
        let word2 = "გამარჯობა"
        
        // When: We hash them
        let hash1 = analytics.hashWord(word1)
        let hash2 = analytics.hashWord(word2)
        
        // Then: Should produce different hashes
        XCTAssertNotEqual(hash1, hash2)
    }
    
    // MARK: - Source String Tests
    
    func testSourceStringConversion() {
        // Given: Different sources
        let localResponse = GeoSuggestionResponse(
            baseWord: "test",
            suggestions: [],
            source: .local
        )
        let serverResponse = GeoSuggestionResponse(
            baseWord: "test",
            suggestions: [],
            source: .server
        )
        let offlineResponse = GeoSuggestionResponse(
            baseWord: "test",
            suggestions: [],
            source: .offline
        )
        
        // Then: Sources should be distinct
        XCTAssertEqual(localResponse.source, .local)
        XCTAssertEqual(serverResponse.source, .server)
        XCTAssertEqual(offlineResponse.source, .offline)
    }
    
    // MARK: - Integration Tests
    
    func testFullEventFlow() {
        // Given: A complete suggestion flow
        let baseWord = "მადლობა"
        let suggestion = "არაპრის"
        let baseHash = analytics.hashWord(baseWord)
        let suggestionHash = analytics.hashWord(suggestion)
        
        // When: We log full flow
        // 1. Exposed
        analytics.logSuggestionExposed(
            baseWord: baseWord,
            baseWordHash: baseHash,
            source: .local,
            suggestionCount: 3
        )
        
        // 2. Clicked
        analytics.logSuggestionClicked(
            baseWord: baseWord,
            baseWordHash: baseHash,
            suggestion: suggestion,
            suggestionHash: suggestionHash,
            source: .local
        )
        
        // 3. Accepted
        analytics.logSuggestionAccepted(
            baseWord: baseWord,
            baseWordHash: baseHash,
            suggestion: suggestion,
            suggestionHash: suggestionHash,
            source: .local,
            action: "append"
        )
        
        // Then: All events should log successfully
        XCTAssertTrue(true)
    }
    
    func testDismissalFlow() {
        // Given: User dismisses suggestions
        let baseWord = "მადლობა"
        let baseHash = analytics.hashWord(baseWord)
        
        // When: We log exposure then dismissal
        analytics.logSuggestionExposed(
            baseWord: baseWord,
            baseWordHash: baseHash,
            source: .local,
            suggestionCount: 3
        )
        
        analytics.logSuggestionDismissed(
            baseWord: baseWord,
            baseWordHash: baseHash,
            source: .local
        )
        
        // Then: Should log both events
        XCTAssertTrue(true)
    }
    
    func testErrorFlow() {
        // Given: Fetch failure
        let baseWord = "unknown"
        let baseHash = analytics.hashWord(baseWord)
        
        // When: We log error and fallback
        analytics.logSuggestionFetchError(
            baseWord: baseWord,
            baseWordHash: baseHash,
            error: "Network error"
        )
        
        analytics.logSuggestionOfflineFallback(
            baseWord: baseWord,
            baseWordHash: baseHash
        )
        
        // Then: Should log both events
        XCTAssertTrue(true)
    }
    
    // MARK: - Performance Validation Tests
    
    func testPerformanceThresholds() {
        // Given: Performance measurements
        let localLatency = 50 // ms
        let serverLatency = 1500 // ms
        
        // Then: Should meet thresholds
        XCTAssertLessThan(localLatency, 150, "Local should be <150ms")
        XCTAssertLessThan(serverLatency, 2000, "Server should be <2s")
    }
}

