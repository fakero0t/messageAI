//
//  EnglishTranslationSuggestionService.swift
//  swift_demo
//
//  Created for AI V3: English→Georgian Translation Suggestions
//

import Foundation
import FirebaseCore
import FirebaseFunctions
import Combine

/// Service to provide English→Georgian translation suggestions with throttling
/// Think of this as a Vuex module with rate limiting and caching logic
@MainActor
class EnglishTranslationSuggestionService: ObservableObject {
    static let shared = EnglishTranslationSuggestionService()
    
    private let englishUsageService = EnglishUsageTrackingService.shared
    private let analytics = TranslationAnalytics.shared
    
    // Throttling state
    private var messagesSinceLast = 0
    private let messagesPerSuggestion = 3
    
    // Cooldown tracking (per-word 24h)
    private var lastSuggestedTimes: [String: Date] = [:]
    private let cooldownSeconds: TimeInterval = 24 * 60 * 60 // 24 hours
    
    // Session tracking (don't suggest same base word more than once)
    private var suggestedThisSession: Set<String> = []
    
    private init() {}
    
    // MARK: - Public API
    
    /// Check if suggestions should be shown for this message
    /// Returns the English word to suggest for, or nil if throttled
    func shouldShowEnglishSuggestion(for text: String, userId: String) -> String? {
        // Increment message counter
        messagesSinceLast += 1
        
        // Check throttle (1 per 3 messages)
        guard messagesSinceLast >= messagesPerSuggestion else {
            analytics.logEnglishSuggestionThrottled(reason: "message_throttle")
            return nil
        }
        
        // Tokenize and find high-frequency English words
        let tokens = tokenize(text)
        let englishTokens = tokens.filter { !GeorgianScriptDetector.containsGeorgian($0) }
        
        for token in englishTokens {
            // Check if high-frequency
            guard englishUsageService.isHighFrequencyEnglishWord(token, userId: userId) else {
                continue
            }
            
            // Check session cooldown
            guard !suggestedThisSession.contains(token) else {
                analytics.logEnglishSuggestionThrottled(reason: "session_cooldown")
                continue
            }
            
            // Check 24h cooldown
            if let lastTime = lastSuggestedTimes[token] {
                let elapsed = Date().timeIntervalSince(lastTime)
                guard elapsed >= cooldownSeconds else {
                    analytics.logEnglishSuggestionThrottled(reason: "24h_cooldown")
                    continue
                }
            }
            
            // Found a valid candidate
            messagesSinceLast = 0
            suggestedThisSession.insert(token)
            lastSuggestedTimes[token] = Date()
            return token
        }
        
        return nil
    }
    
    /// Fetch translation suggestions for a given English word
    func fetchSuggestions(for englishWord: String, conversationId: String) async -> EnglishSuggestionResponse? {
        let normalizedWord = englishWord.lowercased()
        let wordHash = analytics.hashWord(englishWord)
        let startTime = Date()
        
        // Fetch from server via Firebase callable function
        do {
            let suggestions = try await fetchFromServer(englishWord: normalizedWord, conversationId: conversationId)
            
            if let suggestions = suggestions, !suggestions.isEmpty {
                let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
                analytics.logEnglishSuggestionPerformance(
                    englishWord: englishWord,
                    wordHash: wordHash,
                    latencyMs: latencyMs
                )
                
                return EnglishSuggestionResponse(
                    englishWord: englishWord,
                    suggestions: suggestions,
                    source: .server
                )
            }
        } catch {
            print("⚠️ [EnglishSuggestion] Server fetch failed: \(error)")
            analytics.logEnglishSuggestionFetchError(
                englishWord: englishWord,
                wordHash: wordHash,
                error: error.localizedDescription
            )
        }
        
        return nil
    }
    
    /// Fetch suggestions from Firebase Cloud Function
    private func fetchFromServer(englishWord: String, conversationId: String) async throws -> [EnglishSuggestion]? {
        // Check if user is authenticated
        guard let user = AuthenticationService.shared.currentUser else {
            throw NSError(domain: "EnglishSuggestion", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // Get Firebase Functions instance
        let functions = Functions.functions()
        let callable = functions.httpsCallable("suggestEnglishToGeorgian")
        
        let params: [String: Any] = [
            "englishWord": englishWord,
            "userId": user.id,
            "conversationId": conversationId,
            "locale": "ka-GE"
        ]
        
        let result = try await callable.call(params)
        
        // Parse response
        guard let data = result.data as? [String: Any],
              let suggestionsArray = data["suggestions"] as? [[String: Any]] else {
            return nil
        }
        
        let suggestions = suggestionsArray.compactMap { dict -> EnglishSuggestion? in
            guard let word = dict["word"] as? String,
                  let gloss = dict["gloss"] as? String,
                  let formality = dict["formality"] as? String,
                  let contextHint = dict["contextHint"] as? String else {
                return nil
            }
            return EnglishSuggestion(word: word, gloss: gloss, formality: formality, contextHint: contextHint)
        }
        
        return suggestions
    }
    
    /// Reset session state (call when user logs out or app restarts)
    func resetSession() {
        suggestedThisSession.removeAll()
        messagesSinceLast = 0
    }
    
    /// Reset cooldown for a specific word (for testing)
    func resetCooldown(for word: String) {
        lastSuggestedTimes.removeValue(forKey: word)
        suggestedThisSession.remove(word)
    }
    
    // MARK: - Private Helpers
    
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
}

// MARK: - Analytics Extensions

extension TranslationAnalytics {
    func logEnglishSuggestionThrottled(reason: String) {
        print("📊 [Analytics] english_suggestion_throttled reason=\(reason)")
    }
    
    func logEnglishSuggestionPerformance(englishWord: String, wordHash: String, latencyMs: Int) {
        print("📊 [Analytics] english_suggestion_performance word_hash=\(wordHash) latencyMs=\(latencyMs)")
    }
    
    func logEnglishSuggestionFetchError(englishWord: String, wordHash: String, error: String) {
        print("📊 [Analytics] english_suggestion_fetch_error word_hash=\(wordHash) error=\(error)")
    }
    
    func logEnglishSuggestionExposed(englishWord: String, wordHash: String, suggestionCount: Int, userVelocity: Int) {
        print("📊 [Analytics] english_suggestion_exposed word_hash=\(wordHash) suggestion_count=\(suggestionCount) user_velocity=\(userVelocity)")
    }
    
    func logEnglishSuggestionClicked(englishWord: String, wordHash: String, georgianWord: String, georgianHash: String, formality: String) {
        print("📊 [Analytics] english_suggestion_clicked english_hash=\(wordHash) georgian_hash=\(georgianHash) formality=\(formality)")
    }
    
    func logEnglishSuggestionAccepted(englishWord: String, wordHash: String, georgianWord: String, georgianHash: String, action: String) {
        print("📊 [Analytics] english_suggestion_accepted english_hash=\(wordHash) georgian_hash=\(georgianHash) action=\(action)")
    }
    
    func logEnglishSuggestionDismissed(englishWord: String, wordHash: String) {
        print("📊 [Analytics] english_suggestion_dismissed word_hash=\(wordHash)")
    }
}

