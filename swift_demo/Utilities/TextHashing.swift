import Foundation
import CryptoKit

enum TextHashing {
    static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    static func md5(_ text: String) -> String {
        let data = Data(normalized(text).utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}


