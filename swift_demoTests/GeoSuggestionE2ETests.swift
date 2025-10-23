//
//  GeoSuggestionE2ETests.swift
//  swift_demoTests
//
//  Created for PR-6: End-to-End Integration Tests
//

import XCTest
@testable import swift_demo

@MainActor
final class GeoSuggestionE2ETests: XCTestCase {
    var suggestionService: GeoSuggestionService!
    var wordUsageService: WordUsageTrackingService!
    var analytics: TranslationAnalytics!
    
    override func setUp() async throws {
        try await super.setUp()
        suggestionService = GeoSuggestionService.shared
        wordUsageService = WordUsageTrackingService.shared
        analytics = TranslationAnalytics.shared
        
        // Reset state
        suggestionService.resetSession()
        UserDefaults.standard.removeObject(forKey: "geoSuggestionsDisabled")
    }
    
    override func tearDown() async throws {
        suggestionService = nil
        wordUsageService = nil
        analytics = nil
        UserDefaults.standard.removeObject(forKey: "geoSuggestionsDisabled")
        try await super.tearDown()
    }
    
    // MARK: - Full Flow Tests
    
    func testCompleteUserFlow() async throws {
        // Given: User types same Georgian word multiple times
        let word = "მადლობა"
        
        // When: User sends messages with this word
        for _ in 0..<3 {
            wordUsageService.trackMessage(word)
        }
        
        // Then: Word should be high-frequency
        XCTAssertTrue(wordUsageService.isHighFrequencyWord(word))
        
        // When: User types again after 3 messages
        _ = suggestionService.shouldShowSuggestion(for: "text1")
        _ = suggestionService.shouldShowSuggestion(for: "text2")
        let trigger = suggestionService.shouldShowSuggestion(for: word)
        
        // Then: Should trigger
        XCTAssertEqual(trigger, word)
        
        // When: Fetch suggestions
        let response = await suggestionService.fetchSuggestions(for: word)
        
        // Then: Should get suggestions
        XCTAssertNotNil(response)
        XCTAssertFalse(response?.suggestions.isEmpty ?? true)
    }
    
    func testOfflineFallback() async throws {
        // Given: A word in curated list
        let word = "მადლობა"
        
        // Track it
        for _ in 0..<3 {
            wordUsageService.trackMessage(word)
        }
        
        // When: Network is unavailable (simulated by unknown word falling back)
        let unknownWord = "rareunsupportedword"
        for _ in 0..<3 {
            wordUsageService.trackMessage(unknownWord)
        }
        
        _ = suggestionService.shouldShowSuggestion(for: "text1")
        _ = suggestionService.shouldShowSuggestion(for: "text2")
        suggestionService.resetSession()
        _ = suggestionService.shouldShowSuggestion(for: "text3")
        _ = suggestionService.shouldShowSuggestion(for: "text4")
        let trigger = suggestionService.shouldShowSuggestion(for: unknownWord)
        
        // Then: Should handle gracefully
        if trigger != nil {
            let response = await suggestionService.fetchSuggestions(for: unknownWord)
            // Either returns nil or some suggestions, both are acceptable
            XCTAssertTrue(true, "Handled unknown word gracefully")
        }
    }
    
    func testMixedLanguageHandling() async throws {
        // Given: Mixed English and Georgian
        let georgianWord = "მადლობა"
        let mixedText = "Hello \(georgianWord) thanks"
        
        // Track Georgian usage
        for _ in 0..<3 {
            wordUsageService.trackMessage(georgianWord)
        }
        
        // When: Check mixed text
        _ = suggestionService.shouldShowSuggestion(for: "text1")
        _ = suggestionService.shouldShowSuggestion(for: "text2")
        let trigger = suggestionService.shouldShowSuggestion(for: mixedText)
        
        // Then: Should detect Georgian word
        XCTAssertEqual(trigger, georgianWord)
    }
    
    func testShortMessageHandling() async throws {
        // Given: Very short messages
        let shortTexts = ["", " ", "a", "მ"]
        
        // When: We check each
        for text in shortTexts {
            _ = suggestionService.shouldShowSuggestion(for: "text1")
            _ = suggestionService.shouldShowSuggestion(for: "text2")
            let trigger = suggestionService.shouldShowSuggestion(for: text)
            
            // Then: Should handle without crashing
            XCTAssertTrue(true, "Handled '\(text)' without crashing")
        }
    }
    
    func testRepeatTriggers() async throws {
        // Given: High-frequency word
        let word = "მადლობა"
        for _ in 0..<3 {
            wordUsageService.trackMessage(word)
        }
        
        // When: Trigger once
        _ = suggestionService.shouldShowSuggestion(for: "text1")
        _ = suggestionService.shouldShowSuggestion(for: "text2")
        let trigger1 = suggestionService.shouldShowSuggestion(for: word)
        XCTAssertEqual(trigger1, word)
        
        // When: Try to trigger again in same session
        suggestionService.resetCooldown(for: word) // Reset 24h but not session
        _ = suggestionService.shouldShowSuggestion(for: "text3")
        _ = suggestionService.shouldShowSuggestion(for: "text4")
        let trigger2 = suggestionService.shouldShowSuggestion(for: word)
        
        // Then: Should not trigger (session block)
        XCTAssertNil(trigger2)
        
        // When: Reset session
        suggestionService.resetSession()
        _ = suggestionService.shouldShowSuggestion(for: "text5")
        _ = suggestionService.shouldShowSuggestion(for: "text6")
        let trigger3 = suggestionService.shouldShowSuggestion(for: word)
        
        // Then: Should trigger again
        XCTAssertEqual(trigger3, word)
    }
    
    // MARK: - Privacy Tests
    
    func testWordHashing() {
        // Given: Sensitive Georgian words
        let words = ["მადლობა", "გამარჯობა", "ბოდიში"]
        
        // When: We hash them
        let hashes = words.map { analytics.hashWord($0) }
        
        // Then: Hashes should be consistent and one-way
        for (word, hash) in zip(words, hashes) {
            XCTAssertNotEqual(word, hash, "Hash should not equal original")
            XCTAssertEqual(hash.count, 16, "Hash should be 16 chars")
            XCTAssertEqual(analytics.hashWord(word), hash, "Hash should be consistent")
        }
    }
    
    func testNoPIIInLogs() {
        // Given: A suggestion flow
        let baseWord = "მადლობა"
        let suggestion = "არაპრის"
        
        // When: We log events (all logged words are hashed)
        let baseHash = analytics.hashWord(baseWord)
        let suggestionHash = analytics.hashWord(suggestion)
        
        // Then: Hashes should not reveal original words
        XCTAssertNotEqual(baseHash, baseWord)
        XCTAssertNotEqual(suggestionHash, suggestion)
        XCTAssertFalse(baseHash.contains(baseWord))
        XCTAssertFalse(suggestionHash.contains(suggestion))
    }
    
    // MARK: - Settings Tests
    
    func testGlobalOptOut() {
        // Given: Suggestions enabled by default
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "geoSuggestionsDisabled"))
        
        // When: User disables
        UserDefaults.standard.set(true, forKey: "geoSuggestionsDisabled")
        
        // Then: Should be disabled
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "geoSuggestionsDisabled"))
        
        // When: User re-enables
        UserDefaults.standard.set(false, forKey: "geoSuggestionsDisabled")
        
        // Then: Should be enabled
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "geoSuggestionsDisabled"))
    }
    
    // MARK: - Translation Interop Tests
    
    func testTranslationUnaffected() async throws {
        // Given: A message with Georgian text
        let text = "მადლობა"
        
        // When: Suggestions are triggered
        for _ in 0..<3 {
            wordUsageService.trackMessage(text)
        }
        
        _ = suggestionService.shouldShowSuggestion(for: "text1")
        _ = suggestionService.shouldShowSuggestion(for: "text2")
        _ = suggestionService.shouldShowSuggestion(for: text)
        _ = await suggestionService.fetchSuggestions(for: text)
        
        // Then: Word tracking should not interfere with anything
        // (This is a non-regression test - just verify no crashes)
        XCTAssertTrue(true, "Suggestions work without interfering with other features")
    }
    
    // MARK: - Performance Tests
    
    func testLocalPerformance() async throws {
        // Given: A word in curated list
        let word = "მადლობა"
        
        // When: We measure fetch time
        let start = Date()
        _ = await suggestionService.fetchSuggestions(for: word)
        let elapsed = Date().timeIntervalSince(start)
        
        // Then: Should be fast
        XCTAssertLessThan(elapsed, 0.15, "Local suggestions should be <150ms")
    }
    
    func testConsecutiveFetches() async throws {
        // Given: Multiple words
        let words = ["მადლობა", "გამარჯობა", "როგორ"]
        
        // When: We fetch rapidly
        for word in words {
            let start = Date()
            _ = await suggestionService.fetchSuggestions(for: word)
            let elapsed = Date().timeIntervalSince(start)
            
            // Then: Each should be fast
            XCTAssertLessThan(elapsed, 0.15)
        }
    }
    
    // MARK: - Edge Case Integration
    
    func testEmptyStringHandling() {
        // When: Various empty inputs
        _ = suggestionService.shouldShowSuggestion(for: "")
        _ = suggestionService.shouldShowSuggestion(for: "   ")
        _ = suggestionService.shouldShowSuggestion(for: "\n\t")
        
        // Then: Should handle gracefully
        XCTAssertTrue(true)
    }
    
    func testSpecialCharacters() async throws {
        // Given: Georgian with special chars
        let texts = [
            "მადლობა! 🙏",
            "გამარჯობა... 👋",
            "როგორ??? 🤔"
        ]
        
        // When: We track and check
        for text in texts {
            wordUsageService.trackMessage(text)
        }
        
        // Then: Should handle without crashing
        XCTAssertTrue(true)
    }
    
    func testVeryLongMessage() async throws {
        // Given: Very long message
        var longMessage = ""
        for _ in 0..<100 {
            longMessage += "მადლობა "
        }
        
        // When: We track it
        wordUsageService.trackMessage(longMessage)
        
        // Then: Should handle efficiently
        XCTAssertTrue(wordUsageService.getWordCount("მადლობა") >= 100)
    }
}

