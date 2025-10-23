//
//  DefinitionCacheManager.swift
//  swift_demo
//
//  Utility to manage and clear definition cache
//

import Foundation
import SwiftData

/// Manager for definition cache operations
/// Useful for testing and debugging
@MainActor
class DefinitionCacheManager {
    static let shared = DefinitionCacheManager()
    private let container = PersistenceController.shared.container
    
    private init() {}
    
    /// Clear all cached definitions
    func clearAllDefinitions() {
        let context = container.mainContext
        
        let descriptor = FetchDescriptor<DefinitionCacheEntity>()
        
        guard let allEntries = try? context.fetch(descriptor) else {
            print("❌ Failed to fetch definitions")
            return
        }
        
        for entry in allEntries {
            context.delete(entry)
        }
        
        do {
            try context.save()
            print("✅ Cleared \(allEntries.count) cached definitions")
        } catch {
            print("❌ Failed to clear cache: \(error)")
        }
    }
    
    /// Clear cached definition for a specific word
    func clearDefinition(for word: String) {
        let context = container.mainContext
        let normalizedWord = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let descriptor = FetchDescriptor<DefinitionCacheEntity>(
            predicate: #Predicate { entity in
                entity.wordKey == normalizedWord
            }
        )
        
        guard let entry = try? context.fetch(descriptor).first else {
            print("⚠️ No cached definition found for: \(word)")
            return
        }
        
        context.delete(entry)
        
        do {
            try context.save()
            print("✅ Cleared cached definition for: \(word)")
        } catch {
            print("❌ Failed to clear definition: \(error)")
        }
    }
    
    /// Get cache statistics
    func getCacheStats() -> CacheStats {
        let context = container.mainContext
        
        let descriptor = FetchDescriptor<DefinitionCacheEntity>()
        
        guard let allEntries = try? context.fetch(descriptor) else {
            return CacheStats(totalWords: 0, totalAccessCount: 0, oldestCacheDate: nil, newestCacheDate: nil)
        }
        
        let totalAccessCount = allEntries.reduce(0) { $0 + $1.accessCount }
        let oldestDate = allEntries.map { $0.cachedAt }.min()
        let newestDate = allEntries.map { $0.cachedAt }.max()
        
        return CacheStats(
            totalWords: allEntries.count,
            totalAccessCount: totalAccessCount,
            oldestCacheDate: oldestDate,
            newestCacheDate: newestDate
        )
    }
    
    /// List all cached definitions
    func listAllDefinitions() -> [DefinitionCacheEntity] {
        let context = container.mainContext
        
        let descriptor = FetchDescriptor<DefinitionCacheEntity>(
            sortBy: [SortDescriptor(\DefinitionCacheEntity.lastAccessedAt, order: .reverse)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Clear old definitions (older than N days)
    func clearOldDefinitions(olderThanDays days: Int) {
        let context = container.mainContext
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<DefinitionCacheEntity>(
            predicate: #Predicate { entity in
                entity.lastAccessedAt < cutoffDate
            }
        )
        
        guard let oldEntries = try? context.fetch(descriptor) else {
            print("❌ Failed to fetch old definitions")
            return
        }
        
        for entry in oldEntries {
            context.delete(entry)
        }
        
        if !oldEntries.isEmpty {
            do {
                try context.save()
                print("🧹 Cleared \(oldEntries.count) old definitions (older than \(days) days)")
            } catch {
                print("❌ Failed to clear old definitions: \(error)")
            }
        }
    }
}

// MARK: - Models

struct CacheStats {
    let totalWords: Int
    let totalAccessCount: Int
    let oldestCacheDate: Date?
    let newestCacheDate: Date?
    
    var averageAccessCount: Double {
        guard totalWords > 0 else { return 0 }
        return Double(totalAccessCount) / Double(totalWords)
    }
}

