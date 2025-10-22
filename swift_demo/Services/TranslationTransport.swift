import Foundation
import FirebaseAuth

final class TranslationTransport {
    static let shared = TranslationTransport()
    private init() {}
    
    private var baseURL: URL? {
        // Prefer Remote Config later; for now Env var or Info.plist
        if let env = ProcessInfo.processInfo.environment["TRANSLATE_FUNCTION_URL"], let url = URL(string: env) { return url }
        if let urlStr = Bundle.main.object(forInfoDictionaryKey: "TRANSLATE_FUNCTION_URL") as? String, let url = URL(string: urlStr) { return url }
        // Fallback: derive from GoogleService-Info.plist PROJECT_ID
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let projectId = dict["PROJECT_ID"] as? String {
            let urlStr = "https://us-central1-\(projectId).cloudfunctions.net/translateMessage"
            let url = URL(string: urlStr)
            if url != nil { print("🔗 [Translation] Derived function URL from PROJECT_ID: \(urlStr)") }
            return url
        }
        return nil
    }
    
    func requestTranslation(
        messageId: String,
        text: String,
        conversationId: String,
        timestampMs: Int64,
        completion: @escaping (TranslationResult?) -> Void,
        attempt: Int = 0
    ) {
        guard let endpoint = baseURL else {
            print("⚠️ [Translation] Missing TRANSLATE_FUNCTION_URL (set env or Info.plist)")
            completion(nil)
            return
        }
        Task {
            do {
                let token = try await Auth.auth().currentUser?.getIDToken()
                let start = Date()
                print("🌐 [Translation] POST SSE → \(endpoint.absoluteString)")
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                if let token = token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body: [String: Any] = [
                    "messageId": messageId,
                    "text": text,
                    "conversationId": conversationId,
                    "timestamp": timestampMs
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                
                let config = URLSessionConfiguration.default
                config.timeoutIntervalForRequest = 15
                let session = URLSession(configuration: config)
                let (stream, response) = try await session.bytes(for: request)
                guard let http = response as? HTTPURLResponse else { completion(nil); return }
                print("📡 [Translation] HTTP status: \(http.statusCode)")
                guard (200..<300).contains(http.statusCode) else {
                    if let data = try? await URLSession.shared.data(for: request).0, let payload = String(data: data, encoding: .utf8) {
                        print("❌ [Translation] Error payload: \(payload)")
                    }
                    if attempt == 0 {
                        print("🔁 [Translation] Retrying once...")
                        self.requestTranslation(messageId: messageId, text: text, conversationId: conversationId, timestampMs: timestampMs, completion: completion, attempt: 1)
                    } else {
                        completion(nil)
                    }
                    return
                }
                for try await line in stream.lines {
                    if line.hasPrefix("data: ") {
                        let jsonStr = String(line.dropFirst(6))
                        if let data = jsonStr.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let type = obj["type"] as? String, type == "error" {
                                print("❌ [Translation] SSE error: \(obj)")
                                if attempt == 0 {
                                    print("🔁 [Translation] Retrying once after SSE error...")
                                    self.requestTranslation(messageId: messageId, text: text, conversationId: conversationId, timestampMs: timestampMs, completion: completion, attempt: 1)
                                } else {
                                    completion(nil)
                                }
                                return
                            }
                            if let type = obj["type"] as? String, type == "final" {
                                if let translations = obj["translations"] as? [String: String] {
                                    let versions = TranslationVersions(
                                        en: translations["en"] ?? "",
                                        ka: translations["ka"] ?? "",
                                        original: translations["original"] ?? "en"
                                    )
                                    print("✅ [Translation] Received final translations (cached=\(obj["cached"] as? Bool ?? false))")
                                    let result = TranslationResult(messageId: messageId, translations: versions, cached: (obj["cached"] as? Bool) ?? false, latency: nil)
                                    // Store in local cache for instant availability
                                    TranslationCacheService.shared.store(
                                        sourceText: text,
                                        english: result.translations.en,
                                        georgian: result.translations.ka,
                                        confidence: 1.0
                                    )
                                    let elapsed = Int(Date().timeIntervalSince(start) * 1000)
                                    TranslationAnalytics.shared.logTranslationCompleted(
                                        messageId: messageId,
                                        cached: (obj["cached"] as? Bool) ?? false,
                                        latencyMs: elapsed
                                    )
                                    completion(result)
                                    return
                                }
                            }
                        }
                    }
                }
                if attempt == 0 {
                    print("🔁 [Translation] Retrying once after no final event...")
                    self.requestTranslation(messageId: messageId, text: text, conversationId: conversationId, timestampMs: timestampMs, completion: completion, attempt: 1)
                } else {
                    completion(nil)
                }
            } catch {
                print("❌ [Translation] Request failed: \(error)")
                if attempt == 0 {
                    print("🔁 [Translation] Retrying once after failure...")
                    self.requestTranslation(messageId: messageId, text: text, conversationId: conversationId, timestampMs: timestampMs, completion: completion, attempt: 1)
                } else {
                    completion(nil)
                }
            }
        }
    }

    // NL command endpoint
    func requestNLCommand(
        intent: String,
        text: String,
        conversationId: String,
        timestampMs: Int64,
        completion: @escaping (String?) -> Void
    ) {
        guard let base = baseURL else { completion(nil); return }
        // Derive nlCommand URL by replacing path
        let urlStr = base.absoluteString.replacingOccurrences(of: "/translateMessage", with: "/nlCommand")
        guard let url = URL(string: urlStr) else { completion(nil); return }
        Task {
            do {
                let token = try await Auth.auth().currentUser?.getIDToken()
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let token = token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
                let body: [String: Any] = [
                    "intent": intent,
                    "text": text,
                    "conversationId": conversationId,
                    "timestamp": timestampMs
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    print("❌ [NL] HTTP error")
                    completion(nil); return
                }
                if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let result = obj["result"] as? String {
                    completion(result)
                } else {
                    completion(nil)
                }
            } catch {
                print("❌ [NL] Request failed: \(error)")
                completion(nil)
            }
        }
    }
}


