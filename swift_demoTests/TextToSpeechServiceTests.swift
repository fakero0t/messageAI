import XCTest
import AVFoundation
@testable import swift_demo

private final class MockSynth: SpeechSynthesizing {
    private(set) var utterances: [AVSpeechUtterance] = []
    private(set) var stopCalls: Int = 0
    var isSpeaking: Bool { !utterances.isEmpty }

    func speak(_ utterance: AVSpeechUtterance) {
        utterances.append(utterance)
    }

    @discardableResult
    func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool {
        stopCalls += 1
        return true
    }
}

private struct MockAX: AccessibilityProviding {
    let isVoiceOverRunning: Bool
}

final class TextToSpeechServiceTests: XCTestCase {

    func testDebounce_SpeaksOnlyLastLetter() {
        let synth = MockSynth()
        let ax = MockAX(isVoiceOverRunning: false)
        let svc = TextToSpeechService(
            synthesizer: synth,
            accessibilityProvider: ax,
            debounceInterval: 0.05,
            queue: .main
        )

        svc.speakLetter("ა")
        svc.speakLetter("ბ")
        svc.speakLetter("გ")

        // Wait enough for debounce to fire
        let exp = expectation(description: "debounce")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(synth.utterances.count, 1)
        XCTAssertEqual(synth.utterances.first?.speechString, "გ")
        XCTAssertGreaterThanOrEqual(synth.stopCalls, 1)
    }

    func testStop_CancelsPendingAndStops() {
        let synth = MockSynth()
        let ax = MockAX(isVoiceOverRunning: false)
        let svc = TextToSpeechService(
            synthesizer: synth,
            accessibilityProvider: ax,
            debounceInterval: 0.2,
            queue: .main
        )

        svc.speakLetter("ა")
        svc.stop()

        // Wait to ensure no speech executed
        let exp = expectation(description: "no speech")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(synth.utterances.count, 0)
        XCTAssertGreaterThanOrEqual(synth.stopCalls, 1)
    }

    func testVoiceOver_DisablesSpeech() {
        let synth = MockSynth()
        let ax = MockAX(isVoiceOverRunning: true)
        let svc = TextToSpeechService(
            synthesizer: synth,
            accessibilityProvider: ax,
            debounceInterval: 0.05,
            queue: .main
        )

        svc.speakLetter("ა")

        let exp = expectation(description: "no speech when VO on")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(synth.utterances.count, 0)
        XCTAssertEqual(synth.stopCalls, 0)
    }
}
