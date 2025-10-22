import Foundation

final class TranslationAnalytics {
    static let shared = TranslationAnalytics()
    private init() {}
    
    func logTranslationCompleted(messageId: String, cached: Bool, latencyMs: Int) {
        print("📊 [Analytics] translation_completed id=\(messageId) cached=\(cached) latencyMs=\(latencyMs)")
    }
    
    func logNLCommand(intent: String, latencyMs: Int) {
        print("📊 [Analytics] nl_command intent=\(intent) latencyMs=\(latencyMs)")
    }
}


