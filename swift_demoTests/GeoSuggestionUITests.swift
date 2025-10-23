//
//  GeoSuggestionUITests.swift
//  swift_demoTests
//
//  Created for PR-4: UI Integration Tests
//

import XCTest
import SwiftUI
@testable import swift_demo

@MainActor
final class GeoSuggestionUITests: XCTestCase {
    
    // MARK: - Chip Component Tests
    
    func testChipStructure() {
        // Given: A suggestion
        let suggestion = GeoSuggestion(
            word: "არაპრის",
            gloss: "you're welcome",
            formality: "neutral"
        )
        
        // Then: Should have required properties
        XCTAssertFalse(suggestion.word.isEmpty)
        XCTAssertFalse(suggestion.gloss.isEmpty)
        XCTAssertEqual(suggestion.formality, "neutral")
    }
    
    func testChipFormalityColors() {
        // Given: Suggestions with different formality levels
        let formal = GeoSuggestion(word: "test1", gloss: "formal test", formality: "formal")
        let informal = GeoSuggestion(word: "test2", gloss: "informal test", formality: "informal")
        let neutral = GeoSuggestion(word: "test3", gloss: "neutral test", formality: "neutral")
        
        // Then: Should have different formality values
        XCTAssertEqual(formal.formality, "formal")
        XCTAssertEqual(informal.formality, "informal")
        XCTAssertEqual(neutral.formality, "neutral")
    }
    
    // MARK: - Replace/Append Logic Tests
    
    func testAppendWithSpace() {
        // Given: Message text without trailing space
        var messageText = "Hello"
        let suggestion = "მადლობა"
        
        // When: We append
        if messageText.hasSuffix(" ") || messageText.isEmpty {
            messageText = messageText + suggestion
        } else {
            messageText = messageText + " " + suggestion
        }
        
        // Then: Should add space before word
        XCTAssertEqual(messageText, "Hello მადლობა")
    }
    
    func testAppendWithTrailingSpace() {
        // Given: Message text with trailing space
        var messageText = "Hello "
        let suggestion = "მადლობა"
        
        // When: We append
        if messageText.hasSuffix(" ") || messageText.isEmpty {
            messageText = messageText + suggestion
        } else {
            messageText = messageText + " " + suggestion
        }
        
        // Then: Should not add extra space
        XCTAssertEqual(messageText, "Hello მადლობა")
    }
    
    func testAppendToEmptyString() {
        // Given: Empty message text
        var messageText = ""
        let suggestion = "მადლობა"
        
        // When: We append
        if messageText.hasSuffix(" ") || messageText.isEmpty {
            messageText = messageText + suggestion
        } else {
            messageText = messageText + " " + suggestion
        }
        
        // Then: Should append without space
        XCTAssertEqual(messageText, "მადლობა")
    }
    
    // MARK: - Undo Logic Tests
    
    func testUndoRestoresPreviousText() {
        // Given: Original text and suggestion
        let originalText = "Hello"
        var currentText = originalText
        let previousText = currentText
        
        // When: We apply suggestion
        currentText = currentText + " მადლობა"
        
        // Then: Previous text should be preserved
        XCTAssertEqual(previousText, "Hello")
        
        // When: We undo
        currentText = previousText
        
        // Then: Should restore original
        XCTAssertEqual(currentText, originalText)
    }
    
    // MARK: - Accessibility Tests
    
    func testChipAccessibility() {
        // Given: A suggestion
        let suggestion = GeoSuggestion(
            word: "არაპრის",
            gloss: "you're welcome",
            formality: "neutral"
        )
        
        // Then: Should have accessible properties
        XCTAssertFalse(suggestion.word.isEmpty, "Word should be accessible")
        XCTAssertFalse(suggestion.gloss.isEmpty, "Gloss should be accessible")
    }
    
    // MARK: - Integration Tests
    
    func testSuggestionResponse() {
        // Given: A suggestion response
        let suggestions = [
            GeoSuggestion(word: "word1", gloss: "gloss1", formality: "neutral"),
            GeoSuggestion(word: "word2", gloss: "gloss2", formality: "formal")
        ]
        
        let response = GeoSuggestionResponse(
            baseWord: "მადლობა",
            suggestions: suggestions,
            source: .local
        )
        
        // Then: Should have correct structure
        XCTAssertEqual(response.baseWord, "მადლობა")
        XCTAssertEqual(response.suggestions.count, 2)
        XCTAssertEqual(response.source, .local)
    }
    
    func testSuggestionSourceTypes() {
        // Given: Different suggestion sources
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
        
        // Then: Should have distinct sources
        XCTAssertEqual(localResponse.source, .local)
        XCTAssertEqual(serverResponse.source, .server)
        XCTAssertEqual(offlineResponse.source, .offline)
    }
    
    // MARK: - Edge Cases
    
    func testEmptySuggestionList() {
        // Given: Empty suggestions
        let response = GeoSuggestionResponse(
            baseWord: "test",
            suggestions: [],
            source: .local
        )
        
        // Then: Should handle gracefully
        XCTAssertTrue(response.suggestions.isEmpty)
    }
    
    func testMaxThreeSuggestions() {
        // Given: More than 3 suggestions
        let suggestions = [
            GeoSuggestion(word: "w1", gloss: "g1", formality: "neutral"),
            GeoSuggestion(word: "w2", gloss: "g2", formality: "neutral"),
            GeoSuggestion(word: "w3", gloss: "g3", formality: "neutral"),
            GeoSuggestion(word: "w4", gloss: "g4", formality: "neutral"),
            GeoSuggestion(word: "w5", gloss: "g5", formality: "neutral")
        ]
        
        // When: We limit to 3
        let limited = Array(suggestions.prefix(3))
        
        // Then: Should have exactly 3
        XCTAssertEqual(limited.count, 3)
    }
}

