//
//  GeoSuggestion.swift
//  swift_demo
//
//  Created for PR-2: Local Suggestion Engine
//

import Foundation

/// A suggested Georgian word with metadata
struct GeoSuggestion: Codable, Identifiable, Equatable {
    let id = UUID()
    let word: String
    let gloss: String
    let formality: String
    
    enum CodingKeys: String, CodingKey {
        case word, gloss, formality
    }
}

/// Response from suggestion engine
struct GeoSuggestionResponse {
    let baseWord: String
    let suggestions: [GeoSuggestion]
    let source: SuggestionSource
}

enum SuggestionSource {
    case local
    case server
    case offline
}

