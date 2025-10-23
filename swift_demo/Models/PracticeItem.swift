//
//  PracticeItem.swift
//  swift_demo
//
//  Created for AI V4: Context-Aware Smart Practice
//

import Foundation

/// A practice question with one missing letter
/// Think of this as a TypeScript interface for practice data
struct PracticeItem: Codable, Identifiable, Equatable {
    let id: String
    let word: String // Complete Georgian word
    let missingIndex: Int // Position of missing letter (0-based)
    let correctLetter: String // The correct letter that was removed
    let options: [String] // 3 letter choices (includes correctLetter)
    let explanation: String // Brief explanation for learning
    
    /// Display word with underscore at missing position
    var displayWord: String {
        guard missingIndex >= 0 && missingIndex < word.count else {
            return word
        }
        
        var chars = Array(word)
        let index = word.index(word.startIndex, offsetBy: missingIndex)
        chars[word.distance(from: word.startIndex, to: index)] = "_"
        return String(chars)
    }
    
    /// Check if a selected letter is correct
    func isCorrect(_ letter: String) -> Bool {
        return letter == correctLetter
    }
    
    enum CodingKeys: String, CodingKey {
        case id, word, missingIndex, correctLetter, options, explanation
    }
    
    // Default ID generation if not provided
    init(id: String = UUID().uuidString, word: String, missingIndex: Int, correctLetter: String, options: [String], explanation: String) {
        self.id = id
        self.word = word
        self.missingIndex = missingIndex
        self.correctLetter = correctLetter
        self.options = options
        self.explanation = explanation
    }
}

/// Source of practice batch
enum PracticeSource: String, Codable {
    case personalized // Generated from user's message analysis
    case generic // Generic practice for new users
}

/// Response from practice batch generation
struct PracticeBatchResponse: Codable {
    let items: [PracticeItem]
    let source: PracticeSource
    let messageCount: Int
    
    enum CodingKeys: String, CodingKey {
        case items = "batch"
        case source
        case messageCount
    }
}

/// Errors that can occur during practice generation
enum PracticeError: Error, LocalizedError {
    case offline
    case notAuthenticated
    case rateLimitExceeded
    case generationFailed
    case invalidResponse
    case noData
    
    var errorDescription: String? {
        switch self {
        case .offline:
            return "You're offline. Practice requires internet connection."
        case .notAuthenticated:
            return "Please sign in to access practice."
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment."
        case .generationFailed:
            return "Failed to generate practice. Please try again."
        case .invalidResponse:
            return "Received invalid practice data. Please try again."
        case .noData:
            return "Complete more conversations to unlock personalized practice!"
        }
    }
}

