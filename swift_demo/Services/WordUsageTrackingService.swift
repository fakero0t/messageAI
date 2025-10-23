//
//  WordUsageTrackingService.swift
//  swift_demo
//
//  Created for PR-1: Word Usage Tracking & Georgian Detection Foundation
//

import Foundation
import SwiftData
import Combine

/// Service to track Georgian word usage for vocabulary suggestions
/// Think of this as a Vuex store module managing word frequency state
@MainActor
class WordUsageTrackingService: ObservableObject {
    static let shared = WordUsageTrackingService()
    
    private let container = PersistenceController.shared.container
    private let rollingWindowDays = 30
    private let highFrequencyWindowDays = 7
    private let highFrequencyThreshold = 3
    
    private init() {}
    
    // MARK: - Public API
    
    /// Track words from a message (tokenize, filter Georgian, update counts)
    /// In Vue: const trackMessage = (text: string) => { ... }
    func trackMessage(_ text: String) {
        let tokens = tokenize(text)
        let georgianTokens = tokens.filter { isGeorgianWord($0) && !isProperNoun($0) }
        
        for token in georgianTokens {
            updateWordUsage(wordKey: token)
        }
        
        // Clean up old entries periodically
        cleanupOldEntries()
    }
    
    /// Check if a word is high-frequency (7d window, ≥3 uses)
    /// In Vue: const isHighFrequency = (word: string): boolean => { ... }
    func isHighFrequencyWord(_ wordKey: String) -> Bool {
        let context = container.mainContext
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -highFrequencyWindowDays, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<WordUsageEntity>(
            predicate: #Predicate { entity in
                entity.wordKey == wordKey && entity.lastUsedAt >= cutoffDate
            }
        )
        
        guard let entity = try? context.fetch(descriptor).first else {
            return false
        }
        
        return entity.count30d >= highFrequencyThreshold
    }
    
    /// Get count for a specific word in the rolling window
    func getWordCount(_ wordKey: String) -> Int {
        let context = container.mainContext
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -rollingWindowDays, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<WordUsageEntity>(
            predicate: #Predicate { entity in
                entity.wordKey == wordKey && entity.lastUsedAt >= cutoffDate
            }
        )
        
        guard let entity = try? context.fetch(descriptor).first else {
            return 0
        }
        
        return entity.count30d
    }
    
    /// Get all high-frequency words (for testing/debugging)
    func getHighFrequencyWords() -> [String] {
        let context = container.mainContext
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -highFrequencyWindowDays, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<WordUsageEntity>(
            predicate: #Predicate { entity in
                entity.lastUsedAt >= cutoffDate && entity.count30d >= highFrequencyThreshold
            }
        )
        
        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        
        return entities.map { $0.wordKey }
    }
    
    // MARK: - Private Helpers
    
    /// Tokenize text into lowercase words
    /// In Vue/TS: const tokenize = (text: string): string[] => text.toLowerCase().match(/\p{L}+/gu) || []
    private func tokenize(_ text: String) -> [String] {
        let lowercased = text.lowercased()
        var tokens: [String] = []
        
        // Use NSLinguisticTagger for proper word boundary detection
        let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
        tagger.string = lowercased
        
        let range = NSRange(location: 0, length: lowercased.utf16.count)
        let options: NSLinguisticTagger.Options = [.omitWhitespace, .omitPunctuation]
        
        tagger.enumerateTags(in: range, unit: .word, scheme: .tokenType, options: options) { _, tokenRange, _ in
            if let swiftRange = Range(tokenRange, in: lowercased) {
                let token = String(lowercased[swiftRange])
                tokens.append(token)
            }
        }
        
        return tokens
    }
    
    /// Check if a word is Georgian (at least one Georgian character)
    private func isGeorgianWord(_ word: String) -> Bool {
        return GeorgianScriptDetector.containsGeorgian(word)
    }
    
    /// Heuristic to detect proper nouns (starts with uppercase in original text)
    /// For Georgian, we check if the first character is uppercase (Asomtavruli range or Mkhedruli uppercase)
    /// Simplified: if word contains only Georgian and is short, assume not a proper noun for now
    /// More sophisticated logic can be added later
    private func isProperNoun(_ word: String) -> Bool {
        // Simple heuristic: very short words (≤2 chars) are often not proper nouns
        // This is a placeholder; proper noun detection for Georgian is complex
        // For MVP, we'll track all Georgian words and rely on usage patterns
        return false
    }
    
    /// Update or create word usage entity
    private func updateWordUsage(wordKey: String) {
        let context = container.mainContext
        
        let descriptor = FetchDescriptor<WordUsageEntity>(
            predicate: #Predicate { entity in
                entity.wordKey == wordKey
            }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            // Update existing
            existing.count30d += 1
            existing.lastUsedAt = Date()
        } else {
            // Create new
            let newEntity = WordUsageEntity(wordKey: wordKey, count30d: 1, lastUsedAt: Date())
            context.insert(newEntity)
        }
        
        do {
            try context.save()
        } catch {
            print("❌ [WordUsage] Failed to save: \(error)")
        }
    }
    
    /// Clean up entries older than 30 days
    private func cleanupOldEntries() {
        let context = container.mainContext
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -rollingWindowDays, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<WordUsageEntity>(
            predicate: #Predicate { entity in
                entity.lastUsedAt < cutoffDate
            }
        )
        
        guard let oldEntries = try? context.fetch(descriptor) else {
            return
        }
        
        for entry in oldEntries {
            context.delete(entry)
        }
        
        if !oldEntries.isEmpty {
            do {
                try context.save()
                print("🧹 [WordUsage] Cleaned up \(oldEntries.count) old entries")
            } catch {
                print("❌ [WordUsage] Failed to cleanup: \(error)")
            }
        }
    }
}

