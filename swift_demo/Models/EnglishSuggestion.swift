//
//  EnglishSuggestion.swift
//  swift_demo
//
//  Created for AI V3: English→Georgian Translation Suggestions
//

import Foundation

/// A suggested Georgian translation for an English word
struct EnglishSuggestion: Codable, Identifiable, Equatable {
    let id = UUID()
    let word: String
    let gloss: String
    let formality: String
    let contextHint: String
    
    enum CodingKeys: String, CodingKey {
        case word, gloss, formality, contextHint
    }
}

/// Response from English translation suggestion engine
struct EnglishSuggestionResponse {
    let englishWord: String
    let suggestions: [EnglishSuggestion]
    let source: SuggestionSource
}

