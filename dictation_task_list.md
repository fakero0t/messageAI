# Dictation AI – Implementation PRs (Georgian Letter Magnifier + TTS)

This sequence of 5 small, standalone PRs leads to the full feature with clean integration, sub‑2s perceived waits, clear loading/error states, and no feature flags.

---

## PR 1 — GeorgianScriptDetector utility + tests
- **Summary**: Add utilities to detect Georgian script at message/character level. Unit‑tested, no UI changes yet.
- **Changes**:
  - Add `swift_demo/Utilities/GeorgianScriptDetector.swift`
  - Add tests: `swift_demoTests/GeorgianScriptDetectorTests.swift`
- **Key APIs**:
  ```swift
  struct GeorgianScriptDetector {
      static func containsGeorgian(_ text: String) -> Bool
      static func isGeorgian(_ character: Character) -> Bool
  }
  ```
- **Acceptance**:
  - Returns true for Georgian ranges (U+10A0..10FF, U+2D00..2D2F, U+1C90..1CBF).
  - Handles mixed strings and emoji without false positives.
- **Test plan**: Unit tests for positive/negative cases and mixed content.

---

## PR 2 — TextToSpeechService (AVSpeechSynthesizer) + tests
- **Summary**: Add on‑device TTS wrapper for letter‑level speech with debounce and VoiceOver awareness. No UI changes yet.
- **Changes**:
  - Add `swift_demo/Services/TextToSpeechService.swift`
  - Add tests: `swift_demoTests/TextToSpeechServiceTests.swift`
- **Key APIs**:
  ```swift
  final class TextToSpeechService {
      func speakLetter(_ letter: String)
      func stop()
  }
  ```
  - Uses `AVSpeechSynthesizer` with `AVSpeechSynthesisVoice(language: "ka-GE")`; cancels previous utterances; 80–120ms debounce.
- **Acceptance**:
  - No crashes without Georgian voice; gracefully no‑op or fallback voice.
  - Does not speak when VoiceOver is active.
- **Test plan**: Unit tests for debounce, stop behavior, and VoiceOver gating (mockable abstractions).

---

## PR 3 — MagnifierLensView component + hit‑testing helper
- **Summary**: Add reusable magnifier lens UI and a text hit‑testing helper. Not yet wired into chat.
- **Changes**:
  - Add `swift_demo/Views/Components/MagnifierLensView.swift`
  - Add `swift_demo/Views/Chat/TextHitTestingHelper.swift`
  - Add tests: `swift_demoTests/HitTestingHelperTests.swift`
- **Notes**:
  - Lens: circular, blur background, large centered glyph; light shadow; theme‑aware.
  - Hit‑testing: iOS 17+ `TextLayout` path; fallback `UITextView` via `UIViewRepresentable` using TextKit `characterIndex(for:in:)`.
- **Key APIs**:
  ```swift
  struct MagnifierLensView: View {
      var character: Character
  }

  protocol TextHitTesting {
      func characterIndex(at point: CGPoint, in size: CGSize, text: AttributedString) -> Int?
  }
  ```
- **Acceptance**:
  - Lens renders a single glyph crisply at typical chat sizes.
  - Hit‑testing returns stable indices across wrapped lines.
- **Test plan**: Snapshot test for lens; unit tests for hit‑testing on multi‑line text.

---

## PR 4 — GeorgianMagnifierOverlay + gesture + TTS wiring; integrate in MessageBubbleView
- **Summary**: Implement the long‑press + drag overlay that shows the lens, resolves the letter under finger, and speaks it. Integrate only for messages that contain Georgian text.
- **Changes**:
  - Add `swift_demo/Views/Chat/GeorgianMagnifierOverlay.swift`
  - Update `swift_demo/Views/Chat/MessageBubbleView.swift` to wrap Georgian text with the overlay.
  - Add tests: `swift_demoTests/GeorgianMagnifierIntegrationTests.swift`
- **Behavior**:
  - Long‑press (≈200ms) activates; drag updates lens + TTS (debounced); lift cancels.
  - Avoids interfering with copy/translate menus; hides on system menu presentation.
- **Acceptance**:
  - Lens appears only for messages where `GeorgianScriptDetector.containsGeorgian(text)` is true.
  - Letter changes track finger accurately with minimal latency; TTS starts within ~300ms.
- **Test plan**: UI tests to scrub over multi‑line Georgian; ensures no crashes and correct index mapping.

---

## PR 5 — Polish: latency, haptics, loading/error states, and stability tests
- **Summary**: Add subtle haptics on letter change, a minimal loading HUD on first TTS init, and unobtrusive error toasts. Ensure sub‑2s perceived waits. Add performance tests.
- **Changes**:
  - Update `TextToSpeechService` for warm‑up and error surfacing.
  - Update overlay to show brief loading HUD only when needed; add haptics.
  - Add tests: `swift_demoTests/PerformanceAndStabilityTests.swift`.
- **Acceptance**:
  - Interaction success ≥90% on supported devices.
  - Lens visual updates within a frame; TTS TTF ≤300ms (p95 ≤700ms).
  - Clear, non‑blocking error messages; feature remains usable if audio unavailable (lens‑only).
- **Test plan**: Perf tests (frame time, TTS start latency), manual QA for silent mode, missing voice, and VoiceOver on/off.

---

Notes:
- No feature flags are used; the overlay is conditionally applied only to messages that contain Georgian text.
- All network‑independent; privacy‑preserving; on‑device TTS only.
