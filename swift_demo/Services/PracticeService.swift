//
//  PracticeService.swift
//  swift_demo
//
//  Created for AI V4: Context-Aware Smart Practice
//  Similar to GeoSuggestionService pattern - Firebase callable with caching
//

import Foundation
import FirebaseCore
import FirebaseFunctions

/// Service to fetch and manage practice batches
/// Think of this as a Vuex module handling API calls with caching
@MainActor
class PracticeService {
    static let shared = PracticeService()
    
    // In-memory cache (1-hour TTL)
    private var cachedBatch: PracticeBatchResponse?
    private var cacheTimestamp: Date?
    private let cacheTTL: TimeInterval = 3600 // 1 hour
    
    private init() {}
    
    // MARK: - Public API
    
    /// Fetch a practice batch for the current user
    /// Returns cached batch if available and fresh, otherwise calls Firebase
    func fetchPracticeBatch() async throws -> PracticeBatchResponse {
        // Check authentication
        guard let userId = AuthenticationService.shared.currentUser?.id else {
            throw PracticeError.notAuthenticated
        }
        
        // Check in-memory cache
        if let cached = cachedBatch,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheTTL {
            print("✅ [PracticeService] Using cached batch")
            return cached
        }
        
        // Check network connectivity
        guard NetworkMonitor.shared.isConnected else {
            throw PracticeError.offline
        }
        
        // Fetch from Firebase
        print("🔄 [PracticeService] Fetching fresh batch from server...")
        let startTime = Date()
        
        do {
            let functions = Functions.functions()
            let callable = functions.httpsCallable("generatePractice")
            
            let params: [String: Any] = [
                "userId": userId
            ]
            
            let result = try await callable.call(params)
            
            // Parse response
            guard let data = result.data as? [String: Any] else {
                throw PracticeError.invalidResponse
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let response = try JSONDecoder().decode(PracticeBatchResponse.self, from: jsonData)
            
            let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
            print("✅ [PracticeService] Fetched batch: \(response.items.count) items, source: \(response.source.rawValue), latency: \(latencyMs)ms")
            
            // Cache the response
            cachedBatch = response
            cacheTimestamp = Date()
            
            // Log analytics
            logBatchGenerated(response: response, latencyMs: latencyMs, cached: false)
            
            return response
            
        } catch let error as NSError {
            print("❌ [PracticeService] Error: \(error.localizedDescription)")
            
            // Handle specific errors
            if error.domain == "FunctionsErrorDomain" {
                if error.code == 8 { // RESOURCE_EXHAUSTED
                    throw PracticeError.rateLimitExceeded
                }
            }
            
            throw PracticeError.generationFailed
        }
    }
    
    /// Clear cached batch (forces fresh generation on next fetch)
    func clearCache() {
        cachedBatch = nil
        cacheTimestamp = nil
        print("🗑️ [PracticeService] Cache cleared")
    }
    
    /// Get cached batch if available
    func getCachedBatch() -> PracticeBatchResponse? {
        guard let cached = cachedBatch,
              let timestamp = cacheTimestamp,
              Date().timeIntervalSince(timestamp) < cacheTTL else {
            return nil
        }
        return cached
    }
    
    // MARK: - Analytics
    
    private func logBatchGenerated(response: PracticeBatchResponse, latencyMs: Int, cached: Bool) {
        // Log to analytics service
        print("📊 [PracticeAnalytics] practice_batch_generated: { source: \(response.source.rawValue), itemCount: \(response.items.count), latencyMs: \(latencyMs), cached: \(cached) }")
    }
}

