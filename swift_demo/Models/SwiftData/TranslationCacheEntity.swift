import Foundation
import SwiftData

@Model
final class TranslationCacheEntity {
    @Attribute(.unique) var textHash: String
    var englishText: String
    var georgianText: String
    var confidence: Double
    var cachedAt: Date
    var lastAccessedAt: Date
    var accessCount: Int
    
    init(textHash: String, englishText: String, georgianText: String, confidence: Double, cachedAt: Date = Date(), lastAccessedAt: Date = Date(), accessCount: Int = 0) {
        self.textHash = textHash
        self.englishText = englishText
        self.georgianText = georgianText
        self.confidence = confidence
        self.cachedAt = cachedAt
        self.lastAccessedAt = lastAccessedAt
        self.accessCount = accessCount
    }
}


