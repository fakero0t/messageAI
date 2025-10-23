//
//  GeoSuggestionService.swift
//  swift_demo
//
//  Created for PR-2: Local Suggestion Engine, Curated List, Throttling & Filters
//  Updated for PR-3: Backend Embeddings Endpoint & Client Integration
//

import Foundation
import FirebaseCore
import FirebaseFunctions
import Combine

/// Service to provide Georgian word suggestions with throttling and safety filters
/// Think of this as a Vuex module with rate limiting and caching logic
@MainActor
class GeoSuggestionService: ObservableObject {
    static let shared = GeoSuggestionService()
    
    private let wordUsageService = WordUsageTrackingService.shared
    private let cacheService = TranslationCacheService.shared
    private let analytics = TranslationAnalytics.shared
    
    // Throttling state
    private var messagesSinceLast = 0
    private let messagesPerSuggestion = 3
    
    // Cooldown tracking (per-word 24h)
    private var lastSuggestedTimes: [String: Date] = [:]
    private let cooldownSeconds: TimeInterval = 24 * 60 * 60 // 24 hours
    
    // Session tracking (don't suggest same base word more than once)
    private var suggestedThisSession: Set<String> = []
    
    // Curated word map
    private var curatedWords: [String: [GeoSuggestion]] = [:]
    
    // Offensive/archaic filter list
    private let filteredWords: Set<String> = [
        // Placeholder for offensive words (would be populated from a separate config)
    ]
    
    private init() {
        loadCuratedWords()
    }
    
    // MARK: - Public API
    
    /// Check if suggestions should be shown for this message
    /// Returns the word to suggest for, or nil if throttled
    func shouldShowSuggestion(for text: String) -> String? {
        // Increment message counter
        messagesSinceLast += 1
        
        // Check throttle (1 per 3 messages)
        guard messagesSinceLast >= messagesPerSuggestion else {
            analytics.logSuggestionThrottled(reason: "message_throttle")
            return nil
        }
        
        // Tokenize and find high-frequency Georgian words
        let tokens = tokenize(text)
        let georgianTokens = tokens.filter { GeorgianScriptDetector.containsGeorgian($0) }
        
        for token in georgianTokens {
            // Check if high-frequency
            guard wordUsageService.isHighFrequencyWord(token) else {
                continue
            }
            
            // Check session cooldown
            guard !suggestedThisSession.contains(token) else {
                analytics.logSuggestionThrottled(reason: "session_cooldown")
                continue
            }
            
            // Check 24h cooldown
            if let lastTime = lastSuggestedTimes[token] {
                let elapsed = Date().timeIntervalSince(lastTime)
                guard elapsed >= cooldownSeconds else {
                    analytics.logSuggestionThrottled(reason: "24h_cooldown")
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
    
    /// Fetch suggestions for a given Georgian word (local + server fallback)
    func fetchSuggestions(for baseWord: String) async -> GeoSuggestionResponse? {
        let normalizedWord = baseWord.lowercased()
        let baseWordHash = analytics.hashWord(baseWord)
        let startTime = Date()
        
        // Check curated list first
        if let suggestions = curatedWords[normalizedWord] {
            let filtered = filterSuggestions(suggestions)
            guard !filtered.isEmpty else { return nil }
            
            let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
            analytics.logSuggestionPerformance(
                baseWord: baseWord,
                baseWordHash: baseWordHash,
                source: .local,
                latencyMs: latencyMs
            )
            
            return GeoSuggestionResponse(
                baseWord: baseWord,
                suggestions: filtered,
                source: .local
            )
        }
        
        // PR-3: Server fallback via Firebase callable function
        do {
            let serverStartTime = Date()
            let serverSuggestions = try await fetchFromServer(baseWord: baseWord)
            
            if let serverSuggestions = serverSuggestions, !serverSuggestions.isEmpty {
                let latencyMs = Int(Date().timeIntervalSince(serverStartTime) * 1000)
                analytics.logSuggestionPerformance(
                    baseWord: baseWord,
                    baseWordHash: baseWordHash,
                    source: .server,
                    latencyMs: latencyMs
                )
                
                return GeoSuggestionResponse(
                    baseWord: baseWord,
                    suggestions: serverSuggestions,
                    source: .server
                )
            }
        } catch {
            print("⚠️ [GeoSuggestion] Server fetch failed: \(error), falling back to offline")
            analytics.logSuggestionFetchError(
                baseWord: baseWord,
                baseWordHash: baseWordHash,
                error: error.localizedDescription
            )
            analytics.logSuggestionOfflineFallback(
                baseWord: baseWord,
                baseWordHash: baseWordHash
            )
        }
        
        // Offline fallback: return empty (UI will handle gracefully)
        return nil
    }
    
    /// Fetch suggestions from Firebase Cloud Function
    private func fetchFromServer(baseWord: String) async throws -> [GeoSuggestion]? {
        // Check if user is authenticated
        guard AuthenticationService.shared.currentUser != nil else {
            throw NSError(domain: "GeoSuggestion", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // Get Firebase Functions instance
        let functions = Functions.functions()
        let callable = functions.httpsCallable("suggestRelatedWords")
        
        let params: [String: Any] = [
            "base": baseWord,
            "locale": "ka-GE"
        ]
        
        let result = try await callable.call(params)
        
        // Parse response
        guard let data = result.data as? [String: Any],
              let suggestionsArray = data["suggestions"] as? [[String: Any]] else {
            return nil
        }
        
        let suggestions = suggestionsArray.compactMap { dict -> GeoSuggestion? in
            guard let word = dict["word"] as? String,
                  let gloss = dict["gloss"] as? String,
                  let formality = dict["formality"] as? String else {
                return nil
            }
            return GeoSuggestion(word: word, gloss: gloss, formality: formality)
        }
        
        // Filter and return
        return filterSuggestions(suggestions)
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
    
    private func loadCuratedWords() {
        guard let url = Bundle.main.url(forResource: "ka_related_words", withExtension: "json") else {
            print("⚠️ [GeoSuggestion] Could not find ka_related_words.json")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([String: [GeoSuggestion]].self, from: data)
            curatedWords = decoded
            print("✅ [GeoSuggestion] Loaded \(curatedWords.count) curated words")
        } catch {
            print("❌ [GeoSuggestion] Failed to load curated words: \(error)")
        }
    }
    
    private func filterSuggestions(_ suggestions: [GeoSuggestion]) -> [GeoSuggestion] {
        return suggestions.filter { suggestion in
            !filteredWords.contains(suggestion.word.lowercased())
        }
    }
    
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

