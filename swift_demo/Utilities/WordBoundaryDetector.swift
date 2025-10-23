//
//  WordBoundaryDetector.swift
//  swift_demo
//
//  Created for AI V3: Word Definition Lookup
//

import Foundation
import UIKit

/// Utility for detecting word boundaries in text
/// Think of this as a text parsing utility in Vue/TS
struct WordBoundaryDetector {
    
    /// Extract word at a specific character index in text
    /// Strips punctuation but preserves the full context
    static func extractWord(from text: String, at characterIndex: Int) -> (word: String, fullContext: String)? {
        guard characterIndex >= 0 && characterIndex < text.count else {
            return nil
        }
        
        let nsText = text as NSString
        let fullContext = text
        
        // Use NSLinguisticTagger to find word boundaries
        let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
        tagger.string = text
        
        let range = NSRange(location: 0, length: nsText.length)
        var wordRange: NSRange?
        
        tagger.enumerateTags(in: range, unit: .word, scheme: .tokenType, options: []) { _, tokenRange, _ in
            if NSLocationInRange(characterIndex, tokenRange) {
                wordRange = tokenRange
            }
        }
        
        guard let foundRange = wordRange else {
            return nil
        }
        
        let word = nsText.substring(with: foundRange)
        
        // Strip punctuation from word
        let stripped = stripPunctuation(from: word)
        
        guard !stripped.isEmpty else {
            return nil
        }
        
        return (word: stripped, fullContext: fullContext)
    }
    
    /// Strip punctuation from a word
    static func stripPunctuation(from word: String) -> String {
        let punctuation = CharacterSet.punctuationCharacters
        return word.components(separatedBy: punctuation).joined()
    }
    
    /// Check if text contains Georgian characters
    static func containsGeorgian(_ text: String) -> Bool {
        return GeorgianScriptDetector.containsGeorgian(text)
    }
}

