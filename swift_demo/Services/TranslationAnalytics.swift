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
    
    // MARK: - PR-5: Geo Suggestion Analytics
    
    /// Log when suggestions are exposed to the user
    func logSuggestionExposed(baseWord: String, baseWordHash: String, source: SuggestionSource, suggestionCount: Int) {
        let sourceStr = sourceString(for: source)
        print("📊 [Analytics] suggestion_exposed base=\(baseWordHash) source=\(sourceStr) count=\(suggestionCount)")
    }
    
    /// Log when user clicks/taps on a suggestion chip
    func logSuggestionClicked(baseWord: String, baseWordHash: String, suggestion: String, suggestionHash: String, source: SuggestionSource) {
        let sourceStr = sourceString(for: source)
        print("📊 [Analytics] suggestion_clicked base=\(baseWordHash) suggestion=\(suggestionHash) source=\(sourceStr)")
    }
    
    /// Log when user accepts a suggestion (inserts into message)
    func logSuggestionAccepted(baseWord: String, baseWordHash: String, suggestion: String, suggestionHash: String, source: SuggestionSource, action: String) {
        let sourceStr = sourceString(for: source)
        print("📊 [Analytics] suggestion_accepted base=\(baseWordHash) suggestion=\(suggestionHash) source=\(sourceStr) action=\(action)")
    }
    
    /// Log when user dismisses suggestions
    func logSuggestionDismissed(baseWord: String, baseWordHash: String, source: SuggestionSource) {
        let sourceStr = sourceString(for: source)
        print("📊 [Analytics] suggestion_dismissed base=\(baseWordHash) source=\(sourceStr)")
    }
    
    /// Log when suggestion fetch fails
    func logSuggestionFetchError(baseWord: String, baseWordHash: String, error: String) {
        print("📊 [Analytics] suggestion_fetch_error base=\(baseWordHash) error=\(error)")
    }
    
    /// Log when offline fallback is used
    func logSuggestionOfflineFallback(baseWord: String, baseWordHash: String) {
        print("📊 [Analytics] suggestion_offline_fallback base=\(baseWordHash)")
    }
    
    /// Log suggestion fetch performance
    func logSuggestionPerformance(baseWord: String, baseWordHash: String, source: SuggestionSource, latencyMs: Int) {
        let sourceStr = sourceString(for: source)
        print("📊 [Analytics] suggestion_performance base=\(baseWordHash) source=\(sourceStr) latencyMs=\(latencyMs)")
    }
    
    /// Log when throttle blocks a suggestion
    func logSuggestionThrottled(reason: String) {
        print("📊 [Analytics] suggestion_throttled reason=\(reason)")
    }
    
    // MARK: - Helper Methods
    
    private func sourceString(for source: SuggestionSource) -> String {
        switch source {
        case .local:
            return "local"
        case .server:
            return "server"
        case .offline:
            return "offline"
        }
    }
    
    /// Hash a word for privacy (MD5)
    func hashWord(_ word: String) -> String {
        let data = Data(word.lowercased().utf8)
        let hash = data.map { String(format: "%02x", $0) }.joined()
        return String(hash.prefix(16)) // Truncate for brevity
    }
}


