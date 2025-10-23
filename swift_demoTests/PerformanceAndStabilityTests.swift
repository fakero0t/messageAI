import XCTest
@testable import swift_demo

final class PerformanceAndStabilityTests: XCTestCase {

    func testTTSWarmupCompletesQuickly() {
        let svc = TextToSpeechService()
        let exp = expectation(description: "warmup")
        let start = Date()
        svc.warmUp { ok in
            XCTAssertTrue(ok)
            let elapsed = Date().timeIntervalSince(start)
            XCTAssertLessThan(elapsed, 2.0, "Warmup should complete under 2s")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3.0)
    }

    func testDebounceLatencyBudget() {
        let synth = MockSynthForPerf()
        let svc = TextToSpeechService(
            synthesizer: synth,
            accessibilityProvider: SystemAccessibilityProvider(),
            debounceInterval: 0.1,
            queue: .main
        )

        svc.speakLetter("ა")
        let exp = expectation(description: "debounce fire")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(synth.utterancesCount, 1)
    }
}

private final class MockSynthForPerf: SpeechSynthesizing {
    private(set) var utterancesCount = 0
    var isSpeaking: Bool { utterancesCount > 0 }
    func speak(_ utterance: AVSpeechUtterance) { utterancesCount += 1 }
    func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool { true }
}
