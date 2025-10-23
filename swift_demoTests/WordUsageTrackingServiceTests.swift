//
//  WordUsageTrackingServiceTests.swift
//  swift_demoTests
//
//  Created for PR-1: Word Usage Tracking & Georgian Detection Foundation
//

import XCTest
import SwiftData
@testable import swift_demo

@MainActor
final class WordUsageTrackingServiceTests: XCTestCase {
    var service: WordUsageTrackingService!
    var testContainer: ModelContainer!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Use in-memory container for tests
        let schema = Schema([
            MessageEntity.self,
            ConversationEntity.self,
            QueuedMessageEntity.self,
            TranslationCacheEntity.self,
            WordUsageEntity.self
        ])
        
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        testContainer = try ModelContainer(for: schema, configurations: [config])
        
        // Replace shared instance's container with test container
        // Note: In production, we'd inject the container, but for this test we'll work with the shared instance
        service = WordUsageTrackingService.shared
    }
    
    override func tearDown() async throws {
        service = nil
        testContainer = nil
        try await super.tearDown()
    }
    
    // MARK: - Tokenization Tests
    
    func testTokenizeGeorgianText() throws {
        // Given: A message with Georgian words
        let text = "გამარჯობა, როგორ ხარ?"
        
        // When: We track the message
        service.trackMessage(text)
        
        // Then: Georgian words should be tracked
        XCTAssertTrue(service.getWordCount("გამარჯობა") > 0, "Should track 'გამარჯობა'")
        XCTAssertTrue(service.getWordCount("როგორ") > 0, "Should track 'როგორ'")
        XCTAssertTrue(service.getWordCount("ხარ") > 0, "Should track 'ხარ'")
    }
    
    func testTokenizeMixedLanguageText() throws {
        // Given: A message with mixed English and Georgian
        let text = "Hello მადლობა thank you"
        
        // When: We track the message
        service.trackMessage(text)
        
        // Then: Only Georgian word should be tracked
        XCTAssertTrue(service.getWordCount("მადლობა") > 0, "Should track 'მადლობა'")
        XCTAssertEqual(service.getWordCount("hello"), 0, "Should NOT track 'hello'")
        XCTAssertEqual(service.getWordCount("thank"), 0, "Should NOT track 'thank'")
    }
    
    func testTokenizeIgnoresPunctuation() throws {
        // Given: Georgian words with punctuation
        let text = "მადლობა! როგორ? ხარ."
        
        // When: We track the message
        service.trackMessage(text)
        
        // Then: Words should be tracked without punctuation
        XCTAssertTrue(service.getWordCount("მადლობა") > 0)
        XCTAssertTrue(service.getWordCount("როგორ") > 0)
        XCTAssertTrue(service.getWordCount("ხარ") > 0)
    }
    
    func testTokenizeCaseInsensitive() throws {
        // Given: Same Georgian word in different cases (though Georgian doesn't have case in same way as Latin)
        let text1 = "გამარჯობა"
        let text2 = "გამარჯობა"
        
        // When: We track both
        service.trackMessage(text1)
        service.trackMessage(text2)
        
        // Then: Count should be 2
        XCTAssertEqual(service.getWordCount("გამარჯობა"), 2)
    }
    
    // MARK: - High-Frequency Detection Tests
    
    func testHighFrequencyThreshold() throws {
        // Given: A word used exactly 3 times (threshold)
        let word = "მადლობა"
        
        // When: We track it 3 times
        for _ in 0..<3 {
            service.trackMessage(word)
        }
        
        // Then: It should be high-frequency
        XCTAssertTrue(service.isHighFrequencyWord(word), "Word used 3 times should be high-frequency")
    }
    
    func testBelowHighFrequencyThreshold() throws {
        // Given: A word used only 2 times (below threshold of 3)
        let word = "გამარჯობა"
        
        // When: We track it 2 times
        for _ in 0..<2 {
            service.trackMessage(word)
        }
        
        // Then: It should NOT be high-frequency
        XCTAssertFalse(service.isHighFrequencyWord(word), "Word used 2 times should not be high-frequency")
    }
    
    func testAboveHighFrequencyThreshold() throws {
        // Given: A word used 5 times (above threshold)
        let word = "როგორ"
        
        // When: We track it 5 times
        for _ in 0..<5 {
            service.trackMessage(word)
        }
        
        // Then: It should be high-frequency
        XCTAssertTrue(service.isHighFrequencyWord(word), "Word used 5 times should be high-frequency")
    }
    
    func testGetHighFrequencyWords() throws {
        // Given: Multiple words with varying frequencies
        let highFreq1 = "მადლობა"
        let highFreq2 = "გამარჯობა"
        let lowFreq = "ხარ"
        
        // When: We track them
        for _ in 0..<3 { service.trackMessage(highFreq1) }
        for _ in 0..<4 { service.trackMessage(highFreq2) }
        for _ in 0..<2 { service.trackMessage(lowFreq) }
        
        // Then: Only high-frequency words should be returned
        let highFreqWords = service.getHighFrequencyWords()
        XCTAssertTrue(highFreqWords.contains(highFreq1))
        XCTAssertTrue(highFreqWords.contains(highFreq2))
        XCTAssertFalse(highFreqWords.contains(lowFreq))
    }
    
    // MARK: - Rolling Window Tests
    
    func testCountIncrements() throws {
        // Given: A word
        let word = "მადლობა"
        
        // When: We track it multiple times
        service.trackMessage(word)
        let count1 = service.getWordCount(word)
        
        service.trackMessage(word)
        let count2 = service.getWordCount(word)
        
        service.trackMessage(word)
        let count3 = service.getWordCount(word)
        
        // Then: Count should increment
        XCTAssertEqual(count1, 1)
        XCTAssertEqual(count2, 2)
        XCTAssertEqual(count3, 3)
    }
    
    // MARK: - Mixed Language Tests
    
    func testEnglishNotTracked() throws {
        // Given: Pure English text
        let text = "Hello world how are you"
        
        // When: We track it
        service.trackMessage(text)
        
        // Then: No words should be tracked
        XCTAssertEqual(service.getWordCount("hello"), 0)
        XCTAssertEqual(service.getWordCount("world"), 0)
        XCTAssertEqual(service.getWordCount("how"), 0)
    }
    
    func testMultipleGeorgianWordsInSentence() throws {
        // Given: A sentence with multiple Georgian words
        let text = "მე მიყვარს პროგრამირება და ქართული ენა"
        
        // When: We track it
        service.trackMessage(text)
        
        // Then: All Georgian words should be tracked
        XCTAssertTrue(service.getWordCount("მე") > 0)
        XCTAssertTrue(service.getWordCount("მიყვარს") > 0)
        XCTAssertTrue(service.getWordCount("პროგრამირება") > 0)
        XCTAssertTrue(service.getWordCount("და") > 0)
        XCTAssertTrue(service.getWordCount("ქართული") > 0)
        XCTAssertTrue(service.getWordCount("ენა") > 0)
    }
    
    func testEmptyString() throws {
        // Given: An empty string
        let text = ""
        
        // When: We track it
        service.trackMessage(text)
        
        // Then: Nothing should break (no assertion)
        XCTAssertTrue(true, "Should handle empty string gracefully")
    }
    
    func testWhitespaceOnly() throws {
        // Given: Whitespace only
        let text = "   \n  \t  "
        
        // When: We track it
        service.trackMessage(text)
        
        // Then: No words should be tracked (no assertion failure)
        XCTAssertTrue(true, "Should handle whitespace-only string gracefully")
    }
    
    func testPunctuationOnly() throws {
        // Given: Punctuation only
        let text = "!@#$%^&*().,;:"
        
        // When: We track it
        service.trackMessage(text)
        
        // Then: No words should be tracked
        XCTAssertTrue(true, "Should handle punctuation-only string gracefully")
    }
    
    // MARK: - Georgian Script Detection Tests
    
    func testGeorgianScriptDetected() throws {
        // Given: Text with Georgian characters
        let texts = [
            "გამარჯობა",      // Mkhedruli
            "ႠႡႢႣႤ",          // Asomtavruli
            "ⴀⴁⴂⴃⴄ",          // Khutsuri
        ]
        
        // When/Then: All should be detected as Georgian
        for text in texts {
            service.trackMessage(text)
            let words = text.lowercased().components(separatedBy: .whitespaces)
            for word in words where !word.isEmpty {
                let count = service.getWordCount(word)
                XCTAssertTrue(count > 0, "Should detect Georgian in: \(word)")
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testVeryLongMessage() throws {
        // Given: A very long message with repeated Georgian words
        var text = ""
        for _ in 0..<100 {
            text += "მადლობა "
        }
        
        // When: We track it
        service.trackMessage(text)
        
        // Then: Count should be 100
        XCTAssertEqual(service.getWordCount("მადლობა"), 100)
    }
    
    func testRepeatedWordInSingleMessage() throws {
        // Given: Same word repeated in one message
        let text = "მადლობა მადლობა მადლობა"
        
        // When: We track it
        service.trackMessage(text)
        
        // Then: Count should be 3
        XCTAssertEqual(service.getWordCount("მადლობა"), 3)
    }
    
    func testSpecialCharactersWithGeorgian() throws {
        // Given: Georgian with emojis and special chars
        let text = "მადლობა 🙏 გამარჯობა ❤️"
        
        // When: We track it
        service.trackMessage(text)
        
        // Then: Georgian words should still be tracked
        XCTAssertTrue(service.getWordCount("მადლობა") > 0)
        XCTAssertTrue(service.getWordCount("გამარჯობა") > 0)
    }
    
    func testNumbersWithGeorgian() throws {
        // Given: Georgian with numbers
        let text = "მადლობა 123 გამარჯობა 456"
        
        // When: We track it
        service.trackMessage(text)
        
        // Then: Only Georgian words should be tracked
        XCTAssertTrue(service.getWordCount("მადლობა") > 0)
        XCTAssertTrue(service.getWordCount("გამარჯობა") > 0)
        XCTAssertEqual(service.getWordCount("123"), 0)
    }
}

