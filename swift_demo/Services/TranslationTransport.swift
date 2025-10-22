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
        completion: @escaping (TranslationResult?) -> Void
    ) {
        guard let endpoint = baseURL else {
            print("⚠️ [Translation] Missing TRANSLATE_FUNCTION_URL (set env or Info.plist)")
            completion(nil)
            return
        }
        Task {
            do {
                let token = try await Auth.auth().currentUser?.getIDToken()
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
                    "sourceLang": "en", // will be refined later
                    "timestamp": timestampMs
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                
                let (stream, response) = try await URLSession.shared.bytes(for: request)
                guard let http = response as? HTTPURLResponse else { completion(nil); return }
                print("📡 [Translation] HTTP status: \(http.statusCode)")
                guard (200..<300).contains(http.statusCode) else {
                    if let data = try? await URLSession.shared.data(for: request).0, let payload = String(data: data, encoding: .utf8) {
                        print("❌ [Translation] Error payload: \(payload)")
                    }
                    completion(nil); return
                }
                for try await line in stream.lines {
                    if line.hasPrefix("data: ") {
                        let jsonStr = String(line.dropFirst(6))
                        if let data = jsonStr.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let type = obj["type"] as? String, type == "error" {
                                print("❌ [Translation] SSE error: \(obj)")
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
                                    completion(result)
                                    return
                                }
                            }
                        }
                    }
                }
                completion(nil)
            } catch {
                print("❌ [Translation] Request failed: \(error)")
                completion(nil)
            }
        }
    }
}


