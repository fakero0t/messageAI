import Foundation
import SwiftData

final class TranslationCacheService {
    static let shared = TranslationCacheService()
    private let context: ModelContext
    private let maxEntries = 1000
    
    private init(container: ModelContainer = PersistenceController.shared.container) {
        self.context = ModelContext(container)
    }
    
    func get(text: String) -> TranslationResult? {
        let hash = TextHashing.md5(text)
        let descriptor = FetchDescriptor<TranslationCacheEntity>(predicate: #Predicate { $0.textHash == hash })
        guard let cached = try? context.fetch(descriptor).first else { return nil }
        cached.lastAccessedAt = Date()
        cached.accessCount += 1
        try? context.save()
        return TranslationResult(
            messageId: "",
            translations: .init(en: cached.englishText, ka: cached.georgianText, original: "en"),
            cached: true,
            latency: nil
        )
    }
    
    func store(sourceText: String, english: String, georgian: String, confidence: Double) {
        let hash = TextHashing.md5(sourceText)
        let entity = TranslationCacheEntity(textHash: hash, englishText: english, georgianText: georgian, confidence: confidence)
        context.insert(entity)
        try? context.save()
        evictIfNeeded()
    }
    
    private func evictIfNeeded() {
        let sort = [SortDescriptor<TranslationCacheEntity>(\.lastAccessedAt, order: .forward)]
        var descriptor = FetchDescriptor<TranslationCacheEntity>(sortBy: sort)
        if let all = try? context.fetch(descriptor), all.count > maxEntries {
            let toDelete = all.prefix(all.count - maxEntries)
            toDelete.forEach { context.delete($0) }
            try? context.save()
        }
    }
}


