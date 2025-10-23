import Foundation
import AVFoundation

public final class LetterAudioService {
    private var cache: [UInt32: AVAudioPlayer] = [:]
    private let session = AVAudioSession.sharedInstance()

    public init() {}

    @discardableResult
    public func play(letter: Character) -> Bool {
        guard let scalar = letter.unicodeScalars.first else { return false }
        // Ensure only Georgian letters intended for clips
        guard GeorgianScriptDetector.isGeorgian(letter) else { return false }

        do { try configureSessionIfNeeded() } catch {
            return false
        }

        if let player = cache[scalar.value] {
            player.stop()
            player.currentTime = 0
            player.play()
            return true
        }

        guard let url = resolveResourceURL(for: scalar) else { return false }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            cache[scalar.value] = player
            return true
        } catch {
            return false
        }
    }

    public func stop() {
        cache.values.forEach { $0.stop() }
    }

    public func hasClip(for letter: Character) -> Bool {
        guard let scalar = letter.unicodeScalars.first else { return false }
        if cache[scalar.value] != nil { return true }
        return resolveResourceURL(for: scalar) != nil
    }

    public func warmUp() {
        // No-op for now; could preload frequently used letters if desired.
    }

    private func configureSessionIfNeeded() throws {
        // Use ambient so it mixes with others and respects silent switch
        if session.category != .ambient {
            try session.setCategory(.ambient, options: [.mixWithOthers])
        }
        try session.setActive(true, options: [])
    }

    private func resolveResourceURL(for scalar: Unicode.Scalar) -> URL? {
        // Try several naming schemes and extensions
        let hex = String(format: "%04X", scalar.value)
        let candidates = [
            "ka_\(hex)",               // e.g., ka_10D0
            "ka-\(hex)",               // e.g., ka-10D0
            "ka_\(scalar)",            // e.g., ka_ა
            "ka-\(scalar)",            // e.g., ka-ა
            String(scalar)               // raw character filename
        ]
        let exts = ["m4a", "mp3", "wav", "aac"]
        for name in candidates {
            for ext in exts {
                if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                    return url
                }
            }
        }
        return nil
    }
}
