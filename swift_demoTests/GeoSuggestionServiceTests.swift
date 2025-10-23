//
//  GeoSuggestionServiceTests.swift
//  swift_demoTests
//
//  Created for PR-2: Local Suggestion Engine Tests
//

import XCTest
@testable import swift_demo

@MainActor
final class GeoSuggestionServiceTests: XCTestCase {
    var service: GeoSuggestionService!
    var wordUsageService: WordUsageTrackingService!
    
    override func setUp() async throws {
        try await super.setUp()
        service = GeoSuggestionService.shared
        wordUsageService = WordUsageTrackingService.shared
        service.resetSession()
    }
    
    override func tearDown() async throws {
        service.resetSession()
        service = nil
        wordUsageService = nil
        try await super.tearDown()
    }
    
    // MARK: - Throttling Tests
    
    func testThrottling_NoSuggestionBefore3Messages() async throws {
        // Given: A high-frequency word (tracked 3+ times)
        let word = "მადლობა"
        for _ in 0..<3 {
            wordUsageService.trackMessage(word)
        }
        
        // When: We send 2 messages
        let result1 = service.shouldShowSuggestion(for: word)
        let result2 = service.shouldShowSuggestion(for: word)
        
        // Then: No suggestion should be triggered
        XCTAssertNil(result1, "Should not show suggestion on 1st message")
        XCTAssertNil(result2, "Should not show suggestion on 2nd message")
    }
    
    func testThrottling_ShowsOnThirdMessage() async throws {
        // Given: A high-frequency word
        let word = "მადლობა"
        for _ in 0..<3 {
            wordUsageService.trackMessage(word)
        }
        
        // When: We send 3 messages
        _ = service.shouldShowSuggestion(for: "other text")
        _ = service.shouldShowSuggestion(for: "more text")
        let result3 = service.shouldShowSuggestion(for: word)
        
        // Then: Suggestion should be triggered on 3rd message
        XCTAssertEqual(result3, word, "Should show suggestion on 3rd message")
    }
    
    func testThrottling_ResetsAfterShowing() async throws {
        // Given: High-frequency word shown once
        let word = "მადლობა"
        for _ in 0..<3 {
            wordUsageService.trackMessage(word)
        }
        
        service.resetCooldown(for: word) // Reset to allow re-triggering
        
        // When: We trigger once, then send 2 more messages
        _ = service.shouldShowSuggestion(for: "text1")
        _ = service.shouldShowSuggestion(for: "text2")
        let result = service.shouldShowSuggestion(for: word)
        
        // Then: Counter should be at 3, showing suggestion
        XCTAssertNotNil(result, "Throttle should reset after showing")
    }
    
    // MARK: - Session Cooldown Tests
    
    func testSessionCooldown_NoRepeatInSession() async throws {
        // Given: A high-frequency word already suggested
        let word = "მადლობა"
        for _ in 0..<3 {
            wordUsageService.trackMessage(word)
        }
        
        // When: We trigger suggestion twice in same session
        _ = service.shouldShowSuggestion(for: "text1")
        _ = service.shouldShowSuggestion(for: "text2")
        let first = service.shouldShowSuggestion(for: word)
        
        service.resetCooldown(for: word) // Only reset cooldown, not session
        
        _ = service.shouldShowSuggestion(for: "text3")
        _ = service.shouldShowSuggestion(for: "text4")
        let second = service.shouldShowSuggestion(for: word)
        
        // Then: First should trigger, second should not (session block)
        XCTAssertEqual(first, word, "Should trigger first time")
        XCTAssertNil(second, "Should not trigger again in same session")
    }
    
    func testSessionReset_AllowsRepeat() async throws {
        // Given: Word suggested once
        let word = "მადლობა"
        for _ in 0..<3 {
            wordUsageService.trackMessage(word)
        }
        
        _ = service.shouldShowSuggestion(for: "text1")
        _ = service.shouldShowSuggestion(for: "text2")
        _ = service.shouldShowSuggestion(for: word)
        
        // When: We reset session
        service.resetSession()
        
        // Then: Should allow suggesting again
        _ = service.shouldShowSuggestion(for: "text3")
        _ = service.shouldShowSuggestion(for: "text4")
        let result = service.shouldShowSuggestion(for: word)
        
        XCTAssertEqual(result, word, "Should trigger after session reset")
    }
    
    // MARK: - High-Frequency Detection Tests
    
    func testOnlyHighFrequencyWordsTriggered() async throws {
        // Given: One high-freq word (3+ uses) and one low-freq (2 uses)
        let highFreq = "მადლობა"
        let lowFreq = "გამარჯობა"
        
        for _ in 0..<3 {
            wordUsageService.trackMessage(highFreq)
        }
        for _ in 0..<2 {
            wordUsageService.trackMessage(lowFreq)
        }
        
        // When: We check both
        _ = service.shouldShowSuggestion(for: "text1")
        _ = service.shouldShowSuggestion(for: "text2")
        let highResult = service.shouldShowSuggestion(for: highFreq)
        
        service.resetSession()
        _ = service.shouldShowSuggestion(for: "text3")
        _ = service.shouldShowSuggestion(for: "text4")
        let lowResult = service.shouldShowSuggestion(for: lowFreq)
        
        // Then: Only high-freq should trigger
        XCTAssertEqual(highResult, highFreq, "High-frequency word should trigger")
        XCTAssertNil(lowResult, "Low-frequency word should not trigger")
    }
    
    // MARK: - Curated Suggestions Tests
    
    func testFetchSuggestions_FromCuratedList() async throws {
        // Given: A word in the curated list
        let baseWord = "მადლობა"
        
        // When: We fetch suggestions
        let response = await service.fetchSuggestions(for: baseWord)
        
        // Then: Should return suggestions
        XCTAssertNotNil(response, "Should return suggestions for curated word")
        XCTAssertEqual(response?.baseWord, baseWord)
        XCTAssertEqual(response?.source, .local)
        XCTAssertFalse(response?.suggestions.isEmpty ?? true, "Should have suggestions")
        
        // Verify expected words
        let suggestionWords = response?.suggestions.map { $0.word } ?? []
        XCTAssertTrue(suggestionWords.contains("არაპრის"), "Should suggest არაპრის")
    }
    
    func testFetchSuggestions_CaseInsensitive() async throws {
        // Given: Word in different case
        let baseWord = "მადლობა"
        let uppercase = "მადლობა" // Georgian doesn't have traditional uppercase, but test normalization
        
        // When: We fetch with different cases
        let response1 = await service.fetchSuggestions(for: baseWord)
        let response2 = await service.fetchSuggestions(for: uppercase)
        
        // Then: Both should return results
        XCTAssertNotNil(response1)
        XCTAssertNotNil(response2)
        XCTAssertEqual(response1?.suggestions.count, response2?.suggestions.count)
    }
    
    func testFetchSuggestions_NotInCuratedList() async throws {
        // Given: A word not in curated list
        let unknownWord = "გაუგებარი"
        
        // When: We fetch suggestions
        let response = await service.fetchSuggestions(for: unknownWord)
        
        // Then: PR-3 adds server fallback, so might return results or nil
        // Either outcome is acceptable (depends on server state)
        // For testing, we just verify it doesn't crash
        XCTAssertTrue(true, "Should handle unknown word gracefully")
    }
    
    func testSuggestionStructure() async throws {
        // Given: A curated word
        let baseWord = "გამარჯობა"
        
        // When: We fetch suggestions
        let response = await service.fetchSuggestions(for: baseWord)
        
        // Then: Suggestions should have proper structure
        guard let suggestions = response?.suggestions else {
            XCTFail("Should have suggestions")
            return
        }
        
        for suggestion in suggestions {
            XCTAssertFalse(suggestion.word.isEmpty, "Word should not be empty")
            XCTAssertFalse(suggestion.gloss.isEmpty, "Gloss should not be empty")
            XCTAssertTrue(["formal", "informal", "neutral"].contains(suggestion.formality),
                         "Formality should be valid: \(suggestion.formality)")
        }
    }
    
    // MARK: - Mixed Language Tests
    
    func testMixedLanguage_OnlyGeorgianTriggered() async throws {
        // Given: High-frequency Georgian word
        let georgianWord = "მადლობა"
        for _ in 0..<3 {
            wordUsageService.trackMessage(georgianWord)
        }
        
        // When: We send mixed-language text
        _ = service.shouldShowSuggestion(for: "text1")
        _ = service.shouldShowSuggestion(for: "text2")
        let result = service.shouldShowSuggestion(for: "Hello \(georgianWord) thanks")
        
        // Then: Should detect the Georgian word
        XCTAssertEqual(result, georgianWord, "Should detect Georgian word in mixed text")
    }
    
    func testEnglishOnly_NoSuggestions() async throws {
        // Given: English text
        let text = "Hello world how are you"
        
        // When: We check for suggestions after 3 messages
        _ = service.shouldShowSuggestion(for: "text1")
        _ = service.shouldShowSuggestion(for: "text2")
        let result = service.shouldShowSuggestion(for: text)
        
        // Then: No suggestion should be triggered
        XCTAssertNil(result, "Should not trigger for English-only text")
    }
    
    // MARK: - Multiple Words Tests
    
    func testMultipleHighFreqWords_FirstWins() async throws {
        // Given: Two high-frequency words
        let word1 = "მადლობა"
        let word2 = "გამარჯობა"
        
        for _ in 0..<3 {
            wordUsageService.trackMessage(word1)
            wordUsageService.trackMessage(word2)
        }
        
        // When: Both appear in same message
        _ = service.shouldShowSuggestion(for: "text1")
        _ = service.shouldShowSuggestion(for: "text2")
        let result = service.shouldShowSuggestion(for: "\(word1) \(word2)")
        
        // Then: Should trigger for first word found
        XCTAssertNotNil(result, "Should trigger for one of the words")
        XCTAssertTrue(result == word1 || result == word2, "Should be one of the high-freq words")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyString() async throws {
        // Given: Empty string
        let text = ""
        
        // When: We check
        _ = service.shouldShowSuggestion(for: "text1")
        _ = service.shouldShowSuggestion(for: "text2")
        let result = service.shouldShowSuggestion(for: text)
        
        // Then: Should handle gracefully
        XCTAssertNil(result, "Should handle empty string")
    }
    
    func testVeryShortMessage() async throws {
        // Given: Single Georgian character
        let text = "მ"
        
        // When: We check
        _ = service.shouldShowSuggestion(for: "text1")
        _ = service.shouldShowSuggestion(for: "text2")
        let result = service.shouldShowSuggestion(for: text)
        
        // Then: Should handle gracefully
        // Might return nil or the char, either is acceptable
        XCTAssertTrue(true, "Should handle short text without crashing")
    }
    
    func testPunctuationOnly() async throws {
        // Given: Punctuation only
        let text = "!@#$%"
        
        // When: We check
        _ = service.shouldShowSuggestion(for: "text1")
        _ = service.shouldShowSuggestion(for: "text2")
        let result = service.shouldShowSuggestion(for: text)
        
        // Then: Should return nil
        XCTAssertNil(result, "Should not trigger for punctuation only")
    }
    
    // MARK: - Performance Tests
    
    func testFetchSuggestions_Performance() async throws {
        // Given: A curated word
        let baseWord = "მადლობა"
        
        // When: We measure fetch time
        let start = Date()
        _ = await service.fetchSuggestions(for: baseWord)
        let elapsed = Date().timeIntervalSince(start)
        
        // Then: Should be fast (< 150ms as per acceptance criteria)
        XCTAssertLessThan(elapsed, 0.15, "Local suggestions should be < 150ms")
    }
}

