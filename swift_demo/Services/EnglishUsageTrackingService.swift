//
//  EnglishUsageTrackingService.swift
//  swift_demo
//
//  Created for AI V3: English→Georgian Translation Suggestions
//

import Foundation
import SwiftData
import Combine

/// Service to track English word usage for translation suggestions
/// Tracks from BOTH sent and received messages
/// Think of this as a Vuex store module managing English word frequency state
@MainActor
class EnglishUsageTrackingService: ObservableObject {
    static let shared = EnglishUsageTrackingService()
    
    private let container = PersistenceController.shared.container
    private let rollingWindowDays = 7
    private let defaultThreshold = 14
    
    private init() {}
    
    // MARK: - Public API
    
    /// Track words from a message (tokenize, filter English, update counts)
    /// Tracks from both sent and received messages
    func trackMessage(_ text: String, userId: String) {
        let tokens = tokenize(text)
        let englishTokens = tokens.filter { isEnglishWord($0) && !isProperNoun($0) }
        
        for token in englishTokens {
            updateWordUsage(wordKey: token)
        }
        
        // Update user velocity
        updateUserVelocity(userId: userId)
        
        // Clean up old entries periodically
        cleanupOldEntries()
    }
    
    /// Check if a word is high-frequency based on dynamic threshold
    func isHighFrequencyEnglishWord(_ wordKey: String, userId: String) -> Bool {
        let context = container.mainContext
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -rollingWindowDays, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<EnglishUsageEntity>(
            predicate: #Predicate { entity in
                entity.wordKey == wordKey && entity.lastUsedAt >= cutoffDate
            }
        )
        
        guard let entity = try? context.fetch(descriptor).first else {
            return false
        }
        
        let threshold = calculateDynamicThreshold(userId: userId)
        return entity.count7d >= threshold
    }
    
    /// Get count for a specific word in the rolling window
    func getWordCount(_ wordKey: String) -> Int {
        let context = container.mainContext
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -rollingWindowDays, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<EnglishUsageEntity>(
            predicate: #Predicate { entity in
                entity.wordKey == wordKey && entity.lastUsedAt >= cutoffDate
            }
        )
        
        guard let entity = try? context.fetch(descriptor).first else {
            return 0
        }
        
        return entity.count7d
    }
    
    /// Get all high-frequency English words (for testing/debugging)
    func getHighFrequencyWords(userId: String) -> [String] {
        let context = container.mainContext
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -rollingWindowDays, to: Date()) ?? Date()
        let threshold = calculateDynamicThreshold(userId: userId)
        
        let descriptor = FetchDescriptor<EnglishUsageEntity>(
            predicate: #Predicate { entity in
                entity.lastUsedAt >= cutoffDate && entity.count7d >= threshold
            }
        )
        
        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        
        return entities.map { $0.wordKey }
    }
    
    /// Calculate dynamic threshold based on user's messaging velocity
    func calculateDynamicThreshold(userId: String) -> Int {
        let context = container.mainContext
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -rollingWindowDays, to: Date()) ?? Date()
        
        // Get message count from last 7 days
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: #Predicate { msg in
                msg.senderId == userId && msg.timestamp >= cutoffDate
            }
        )
        
        let messageCount = (try? context.fetchCount(descriptor)) ?? 0
        let avgPerDay = Double(messageCount) / Double(rollingWindowDays)
        
        // Scale threshold based on activity level
        if avgPerDay < 5 {
            return 7   // Low activity: suggest after 7 uses
        } else if avgPerDay < 20 {
            return 14  // Medium activity: suggest after 14 uses
        } else {
            return 21  // High activity: suggest after 21 uses
        }
    }
    
    // MARK: - Private Helpers
    
    /// Tokenize text into lowercase words
    private func tokenize(_ text: String) -> [String] {
        let lowercased = text.lowercased()
        var tokens: [String] = []
        
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
    
    /// Check if a word is English (no Georgian characters)
    private func isEnglishWord(_ word: String) -> Bool {
        return !GeorgianScriptDetector.containsGeorgian(word)
    }
    
    /// Heuristic to detect proper nouns
    /// For English, we can skip this for MVP
    private func isProperNoun(_ word: String) -> Bool {
        // Simple heuristic: very short words (≤2 chars) might not be useful
        // For MVP, we'll track most English words
        return word.count <= 2
    }
    
    /// Update or create word usage entity
    private func updateWordUsage(wordKey: String) {
        let context = container.mainContext
        
        let descriptor = FetchDescriptor<EnglishUsageEntity>(
            predicate: #Predicate { entity in
                entity.wordKey == wordKey
            }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            // Update existing
            existing.count7d += 1
            existing.lastUsedAt = Date()
        } else {
            // Create new
            let newEntity = EnglishUsageEntity(wordKey: wordKey, count7d: 1, lastUsedAt: Date())
            context.insert(newEntity)
        }
        
        do {
            try context.save()
        } catch {
            print("❌ [EnglishUsageTracking] Failed to save: \(error)")
        }
    }
    
    /// Update user velocity in recent entities
    private func updateUserVelocity(userId: String) {
        let context = container.mainContext
        let velocity = Double(calculateDynamicThreshold(userId: userId))
        
        // Store velocity in UserDefaults for quick access
        UserDefaults.standard.set(velocity, forKey: "englishSuggestionVelocity_\(userId)")
    }
    
    /// Clean up entries older than 7 days
    private func cleanupOldEntries() {
        let context = container.mainContext
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -rollingWindowDays, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<EnglishUsageEntity>(
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
                print("🧹 [EnglishUsageTracking] Cleaned up \(oldEntries.count) old entries")
            } catch {
                print("❌ [EnglishUsageTracking] Failed to cleanup: \(error)")
            }
        }
    }
}

