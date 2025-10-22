import Foundation

struct TranslationVersions: Codable, Equatable {
    var en: String
    var ka: String
    var original: String // "en" or "ka"
}

struct TranslationResult: Codable, Equatable {
    var messageId: String
    var translations: TranslationVersions
    var cached: Bool
    var latency: TimeInterval?
}


