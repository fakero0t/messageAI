//
//  DefinitionService.swift
//  swift_demo
//
//  Created for AI V3: Word Definition Lookup
//

import Foundation
import SwiftData
import FirebaseCore
import FirebaseAuth
import FirebaseFunctions
import Combine

/// Service to fetch Georgian word definitions with caching
/// Think of this as a Vuex module with async state management
@MainActor
class DefinitionService: ObservableObject {
    static let shared = DefinitionService()
    
    private let container = PersistenceController.shared.container
    private let analytics = TranslationAnalytics.shared
    private let networkMonitor = NetworkMonitor.shared
    
    // Rate limiting state
    private var requestTimestamps: [Date] = []
    private let maxRequestsPerMinute = 30
    
    private init() {}
    
    // MARK: - Public API
    
    /// Fetch definition for a Georgian word
    /// Returns cached result immediately if available, otherwise fetches from server
    func fetchDefinition(
        word: String,
        conversationId: String,
        fullContext: String
    ) async throws -> DefinitionResult {
        let normalizedWord = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let startTime = Date()
        
        // Check rate limit
        try checkRateLimit()
        
        // Log request
        analytics.logDefinitionRequested(word: word, conversationId: conversationId)
        
        // Check local cache first
        if let cached = getCachedDefinition(for: normalizedWord) {
            print("💾 [DefinitionService] Cache hit for word: \(normalizedWord)")
            analytics.logDefinitionCacheHit(word: word)
            
            let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
            analytics.logDefinitionDisplayed(word: word, latencyMs: latencyMs, cached: true)
            
            return DefinitionResult(
                word: word,
                definition: cached.definition,
                example: cached.example,
                cached: true
            )
        }
        
        // Check network connectivity
        guard networkMonitor.isConnected else {
            print("⚠️ [DefinitionService] Offline, cannot fetch definition")
            analytics.logDefinitionOfflineBlocked(word: word)
            throw DefinitionError.offline
        }
        
        // Fetch from server
        print("🌐 [DefinitionService] Fetching from server for word: \(normalizedWord)")
        let result = try await fetchFromServer(
            word: normalizedWord,
            conversationId: conversationId,
            fullContext: fullContext
        )
        
        // Cache result locally
        cacheDefinition(word: normalizedWord, definition: result.definition, example: result.example)
        
        let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
        analytics.logDefinitionDisplayed(word: word, latencyMs: latencyMs, cached: false)
        
        return result
    }
    
    // MARK: - Private Helpers
    
    /// Get cached definition from SwiftData
    private func getCachedDefinition(for word: String) -> DefinitionCacheEntity? {
        let context = container.mainContext
        
        let descriptor = FetchDescriptor<DefinitionCacheEntity>(
            predicate: #Predicate { entity in
                entity.wordKey == word
            }
        )
        
        guard let cached = try? context.fetch(descriptor).first else {
            return nil
        }
        
        // Update access stats
        cached.lastAccessedAt = Date()
        cached.accessCount += 1
        try? context.save()
        
        return cached
    }
    
    /// Cache definition in SwiftData
    private func cacheDefinition(word: String, definition: String, example: String) {
        let context = container.mainContext
        
        let entity = DefinitionCacheEntity(
            wordKey: word,
            definition: definition,
            example: example
        )
        
        context.insert(entity)
        
        do {
            try context.save()
            print("✅ [DefinitionService] Cached definition for: \(word)")
        } catch {
            print("❌ [DefinitionService] Failed to cache definition: \(error)")
        }
        
        // Cleanup old entries (keep most recent 1000)
        cleanupOldEntries()
    }
    
    /// Fetch definition from Firebase Function via SSE
    private func fetchFromServer(
        word: String,
        conversationId: String,
        fullContext: String
    ) async throws -> DefinitionResult {
        // Get auth token from Firebase Auth
        guard let token = try? await Auth.auth().currentUser?.getIDToken() else {
            throw DefinitionError.notAuthenticated
        }
        
        // Build request URL
        let projectId = "messageai-cbd8a" // Your Firebase project ID
        let region = "us-central1"
        let functionUrl = "https://\(region)-\(projectId).cloudfunctions.net/getWordDefinition"
        
        guard let url = URL(string: functionUrl) else {
            throw DefinitionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "word": word,
            "conversationId": conversationId,
            "fullContext": fullContext,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30
        
        // Make request with SSE support
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DefinitionError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw DefinitionError.serverError(statusCode: httpResponse.statusCode)
        }
        
        // Parse SSE response
        let responseText = String(data: data, encoding: .utf8) ?? ""
        let lines = responseText.components(separatedBy: "\n")
        
        for line in lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                guard let jsonData = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    continue
                }
                
                // Check for error
                if let error = json["error"] as? String {
                    throw DefinitionError.serverError(statusCode: 500)
                }
                
                // Parse definition result
                if let definition = json["definition"] as? String,
                   let example = json["example"] as? String {
                    return DefinitionResult(
                        word: word,
                        definition: definition,
                        example: example,
                        cached: false
                    )
                }
            }
        }
        
        throw DefinitionError.invalidResponse
    }
    
    /// Check rate limit (30 requests per minute)
    private func checkRateLimit() throws {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)
        
        // Remove old timestamps
        requestTimestamps = requestTimestamps.filter { $0 > oneMinuteAgo }
        
        // Check limit
        guard requestTimestamps.count < maxRequestsPerMinute else {
            throw DefinitionError.rateLimitExceeded
        }
        
        // Add current timestamp
        requestTimestamps.append(now)
    }
    
    /// Cleanup old cache entries (keep most recent 1000)
    private func cleanupOldEntries() {
        let context = container.mainContext
        
        let descriptor = FetchDescriptor<DefinitionCacheEntity>(
            sortBy: [SortDescriptor(\DefinitionCacheEntity.lastAccessedAt, order: .reverse)]
        )
        
        guard let allEntries = try? context.fetch(descriptor),
              allEntries.count > 1000 else {
            return
        }
        
        // Delete oldest entries
        let entriesToDelete = allEntries.suffix(from: 1000)
        for entry in entriesToDelete {
            context.delete(entry)
        }
        
        do {
            try context.save()
            print("🧹 [DefinitionService] Cleaned up \(entriesToDelete.count) old entries")
        } catch {
            print("❌ [DefinitionService] Failed to cleanup: \(error)")
        }
    }
}

// MARK: - Models

struct DefinitionResult {
    let word: String
    let definition: String
    let example: String
    let cached: Bool
}

enum DefinitionError: LocalizedError {
    case offline
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .offline:
            return "You're offline. Definition lookup requires internet connection."
        case .notAuthenticated:
            return "Authentication required"
        case .invalidURL:
            return "Invalid request URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error (\(code))"
        case .rateLimitExceeded:
            return "Too many requests. Please try again later."
        }
    }
}

// MARK: - Analytics Extensions

extension TranslationAnalytics {
    func logDefinitionRequested(word: String, conversationId: String) {
        let wordHash = hashWord(word)
        print("📊 [Analytics] definition_requested word_hash=\(wordHash) conversation_id=\(conversationId)")
    }
    
    func logDefinitionDisplayed(word: String, latencyMs: Int, cached: Bool) {
        let wordHash = hashWord(word)
        print("📊 [Analytics] definition_displayed word_hash=\(wordHash) latencyMs=\(latencyMs) cached=\(cached)")
    }
    
    func logDefinitionCacheHit(word: String) {
        let wordHash = hashWord(word)
        print("📊 [Analytics] definition_cache_hit word_hash=\(wordHash)")
    }
    
    func logDefinitionOfflineBlocked(word: String) {
        let wordHash = hashWord(word)
        print("📊 [Analytics] definition_offline_blocked word_hash=\(wordHash)")
    }
}

