# geo_suggestions_tasks.md — PR Breakdown for Smart Georgian Vocabulary Suggestions

## Overview
Six sequential PRs to implement the full feature (no flags), covering data tracking, local + server suggestions, UI/UX, analytics, and privacy. Each PR includes acceptance criteria and dependencies.

## Decisions Locked
- Accept behavior: replace selected token; else append at end. Insert Georgian word only. Provide undo.
- Embeddings provider: OpenAI `text-embedding-3-small` via Cloud Functions (`OPENAI_API_KEY`).
- High-frequency trigger: 7-day window, ≥3 uses.

## PR 1 — Word Usage Tracking & Georgian Detection Foundation
**Summary:** Add per‑user Georgian token tracking and integrate automatic detection.

**Changes:**
- Add `Models/SwiftData/WordUsageEntity.swift` (schema: `wordKey`, `count30d`, `lastUsedAt`).
- Hook into composer input pipeline (likely `ViewModels/ChatViewModel.swift`) to tokenize Georgian content and update counts.
- Reuse `Utilities/GeorgianScriptDetector.swift`; ensure mixed‑language handling and proper‑noun avoidance.
- Unit tests in `swift_demoTests/` for tokenization, counting windows, mixed‑language.

**Acceptance:**
- Only Georgian tokens counted; proper nouns excluded.
- Rolling window aggregation works; counts persist across sessions.
- 7-day window, ≥3 uses triggers high-frequency flag.
- No regressions to sending/translation flows.

**Depends on:** none.

---

## PR 2 — Local Suggestion Engine, Curated List, Throttling & Filters
**Summary:** Implement local tier suggestions with curated list, safety filter, cooldowns, and caching.

**Changes:**
- Add `Services/GeoSuggestionService.swift` to orchestrate triggers, throttles (1 per 3 messages), 24h per‑word cooldown, and suggestion fetch pipeline.
- Bundle curated related-words list for ~200 Georgian words (e.g., `Resources/ka_related_words.json`).
- Integrate caching via `Services/TranslationCacheService.swift` for local tier.
- Add sensitive/archaic/offensive filter list and formality metadata.
- Tests for throttling, cooldowns, local lookup, filters.

**Acceptance:**
- When a high‑frequency Georgian token is typed (7d, ≥3 uses), local suggestions return ≤150ms p95.
- Throttling/cooldowns respected; filtered outputs never surface.

**Depends on:** PR 1.

---

## PR 3 — Backend Embeddings Endpoint (OpenAI) & Client Integration
**Summary:** Add Cloud Function and client to fetch semantically related Georgian terms with cache using OpenAI embeddings.

**Changes:**
- In `functions/index.js`: implement `suggestRelatedWords` (HTTPS callable). Inputs `{ base, locale: 'ka-GE' }`; outputs `{ base, suggestions[{ word, gloss, formality }], ttl }`.
- Use OpenAI `text-embedding-3-small`; configure `OPENAI_API_KEY` via Functions config. Add request validation, rate limiting, and retry/backoff.
- Apply safety filters, profanity/archaic filters, proper‑noun avoidance; cache by base word with TTL.
- Add client call in `Services/TranslationTransport.swift` or `GeoSuggestionService.swift` with graceful offline fallback to local tier.
- Tests: unit for function (mock OpenAI), integration stub in app.

**Acceptance:**
- p95 ≤ 2s, valid payload schema, sensible neighbors for common words.
- Caching reduces repeat latency and load; errors fall back to local tier without UI jank.

**Depends on:** PR 2 (service orchestration exists).

---

## PR 4 — UI: Composer Chips, Context Menu, Replace/Append + Undo, Loading/Error, A11y
**Summary:** Build UI surfaces and interactions with locked insertion behavior.

**Changes:**
- New reusable chip component in `Views/Components/` (e.g., `SuggestionChip.swift`).
- Integrate chips above composer in `Views/Chat/*` and contextual menu action "Try related words".
- Accept behavior: if a Georgian token is selected, replace it; else append suggestion (Georgian word only) to end (prefix with comma/space as needed). Provide undo snackbar.
- Loading skeleton within 150ms; graceful error text; VoiceOver labels.
- Tests: snapshot and interaction tests in `swift_demoTests/` (selection detection, replace vs append, undo).

**Acceptance:**
- Chips appear only for Georgian tokens (7d, ≥3 uses), respect throttles.
- Replace/append logic works reliably; only Georgian word inserted; undo restores prior text.
- No layout regressions; a11y labels present.

**Depends on:** PRs 1–3.

---

## PR 5 — Analytics, Metrics, and Performance Budgets
**Summary:** Instrument telemetry and enforce perf targets.

**Changes:**
- Log `suggestion_exposed`, `suggestion_clicked`, `suggestion_accepted`, `suggestion_dismissed`, `fetch_error`, `offline_fallback` via `Services/TranslationAnalytics.swift`.
- Add perf timers for local vs server paths.
- Dashboard spec (brief) and thresholds encoded for alerts (docstring/config).
- Tests: verify event emission and parameter payloads (include base hash, path=local/server, action=replace|append).

**Acceptance:**
- Events fire with correct context and action types.
- p95 local ≤150ms and server ≤2s validated in dev profiling.

**Depends on:** PRs 2–4.

---

## PR 6 — Privacy, Controls, Final Integration & E2E
**Summary:** User controls, privacy guarantees, and end‑to‑end hardening.

**Changes:**
- Settings toggle (global opt‑out) and per‑chat mute; surface in existing settings UI.
- Ensure only hashed tokens are synced; no message text stored server‑side.
- Content filter enforcement on both client and server paths.
- End‑to‑end tests: offline fallback, mixed‑language, short messages, repeat triggers; confirm real‑time translation unaffected.

**Acceptance:**
- Opt‑out fully disables suggestions; per‑chat mute respected.
- No PII leakage beyond hashed tokens; filters applied consistently.
- E2E scenarios pass and do not degrade translation or commands.

**Depends on:** PRs 1–5.

---

## Coverage Matrix (key requirements → PRs)
- Georgian‑only detection: PR 1, PR 4 acceptance gates
- Track high‑frequency words (7d, ≥3): PR 1
- Related word suggestions: PR 2 (local), PR 3 (server via OpenAI)
- Fast responses: PR 2 (≤150ms local), PR 3 (≤2s server), PR 5 validation
- Clean UI integration, loading/error, undo: PR 4
- Natural language command interop: PR 4/6 non‑regression
- Real‑time translation unaffected: PR 4/6 non‑regression
- Cultural/formality hints, slang/idioms glosses: PR 2/3 payload and rendering
- Privacy & controls: PR 6
- Telemetry & KPIs: PR 5

---

## Notes for Implementers (Vue/TypeScript mental model)
Think of PR 1–3 as building a Vuex store + local dictionary + server API in a Vue app, with PR 4 wiring UI chips into a composer and PR 5–6 adding analytics and privacy toggles. Swift services mirror TS services, and Functions mirror a Node API route.

