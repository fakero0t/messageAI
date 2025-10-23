import Foundation
import AVFoundation
import UIKit

public protocol SpeechSynthesizing {
    var isSpeaking: Bool { get }
    func speak(_ utterance: AVSpeechUtterance)
    @discardableResult
    func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool
}

extension AVSpeechSynthesizer: SpeechSynthesizing {
    public func speak(_ utterance: AVSpeechUtterance) {
        self.speak(utterance)
    }
}

public protocol AccessibilityProviding {
    var isVoiceOverRunning: Bool { get }
}

public struct SystemAccessibilityProvider: AccessibilityProviding {
    public init() {}
    public var isVoiceOverRunning: Bool { UIAccessibility.isVoiceOverRunning }
}

public final class TextToSpeechService {
    private let synthesizer: SpeechSynthesizing
    private let accessibilityProvider: AccessibilityProviding
    private let debounceInterval: TimeInterval
    private var pendingWorkItem: DispatchWorkItem?
    private let queue: DispatchQueue
    private(set) public var isWarmedUp: Bool = false

    public init(
        synthesizer: SpeechSynthesizing = AVSpeechSynthesizer(),
        accessibilityProvider: AccessibilityProviding = SystemAccessibilityProvider(),
        debounceInterval: TimeInterval = 0.1,
        queue: DispatchQueue = .main
    ) {
        self.synthesizer = synthesizer
        self.accessibilityProvider = accessibilityProvider
        self.debounceInterval = debounceInterval
        self.queue = queue
    }

    // MARK: - Voice Support
    public func hasGeorgianVoice() -> Bool {
        AVSpeechSynthesisVoice.speechVoices().contains { $0.language.lowercased() == "ka-ge" }
    }

    public func warmUp(completion: @escaping (Bool) -> Void) {
        if isWarmedUp {
            completion(true)
            return
        }
        // Lightweight warm-up: query voices and create an utterance (not spoken)
        _ = AVSpeechSynthesisVoice(language: "ka-GE")
        // Simulate minimal setup time on next runloop to keep UI responsive
        queue.async { [weak self] in
            self?.isWarmedUp = true
            completion(true)
        }
    }

    // MARK: - Speaking
    public func speakLetter(_ letter: String) {
        let trimmed = letter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !accessibilityProvider.isVoiceOverRunning else { return }

        pendingWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            _ = self.synthesizer.stopSpeaking(at: .immediate)

            let utterance = AVSpeechUtterance(string: trimmed)
            if let kaVoice = AVSpeechSynthesisVoice(language: "ka-GE") {
                utterance.voice = kaVoice
            }
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.volume = 1.0
            utterance.preUtteranceDelay = 0
            utterance.postUtteranceDelay = 0

            self.synthesizer.speak(utterance)
        }
        pendingWorkItem = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    public func stop() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        _ = synthesizer.stopSpeaking(at: .immediate)
    }
}
