## AI Translation (EN↔KA) – PR Plan (≤10 PRs)

Scope: Implement bilingual translation with double‑tap reveal, local (SwiftData)/Firestore caching, Firebase Functions, LLM integration, analytics, and tests. Auto‑translate all new messages (sent and received). Only new messages are translated (no backfill). No opt‑out now; design to support a future language‑learning toggle. Each PR is self‑contained, backward compatible, and gated with a feature flag `aiTranslation.enabled`.

Conventions
- Branch naming: `feature/ai-translation/pr-0X-<slug>`
- Feature flag path: iOS `RemoteConfig.aiTranslation.enabled` (fallback to Info.plist bool); Functions `process.env.AI_TRANSLATION_ENABLED`.
- Cache collection: Firestore `translationCache` (textHash key)
- Model: OpenAI GPT-4o (your OpenAI key)

Standards & Targets
- RAG: Include last 10 messages (configurable) as conversation context in every LLM call.
- Caching: Local SwiftData LRU + Firestore global cache. Target ≥40% cache hit after warm.
- Performance: p95 <8s for translations; p95 <15s for NL command “agent” calls; cache-hit <2s end-to-end; UI reveal animation ~300ms.
- NL commands: Support natural language actions (explain slang, adjust tone, cultural hint) with ≥90% success on test set; simple actions <2s when cached.
- UI/UX: Contextual menu in message bubble; clean integration with chat; clear loading/error states.
- Quality: Accurate, natural real-time translation; automatic language detection; mixed-language segmentation; helpful cultural hints; tone/formality adjustments; clear slang/idiom explanations.
- Integration: Does not break typing indicators, read receipts, notifications; reuse existing rate limiting.

---

### PR 01 – Foundations: Feature Flag, Types, Message Schema, SwiftData Entity
Summary
- Introduces feature flag, shared types, message `versions` shape, and local SwiftData `TranslationCacheEntity` with LRU helpers. No user‑visible UI.

Changes
- iOS
  - Add `FeatureFlags` helper (Remote Config + Info.plist fallback).
  - Define models: `TranslationResult`, `TranslationVersions { en, ka, original }`.
  - Create SwiftData model/entity `TranslationCacheEntity` + service for get/store/evict (LRU ~1000).
  - Add simple MD5 text hashing utility.
- Backend (Firebase Functions)
  - Add `AI_TRANSLATION_ENABLED` config plumbing; no endpoints yet.
- Data/Config
  - Firestore message schema documentation for `versions` and `metadata.translatedAt`.

Tests
- iOS unit tests: hash utility; SwiftData store/retrieve; LRU eviction.

Acceptance
- App builds and runs with feature flag OFF; no UI change; tests pass.

Setup/Deploy
- iOS: Add Info.plist key `AITranslationEnabled` (bool, default false) if Remote Config unavailable.
- Remote Config: create key `aiTranslation.enabled` (default false).
- No backend deploy needed yet.

---

### PR 02 – Firebase Translate Function (HTTP SSE‑only) + Global Cache
Summary
- Adds an HTTPS Function that streams translation results via SSE. Implements Firestore global cache `translationCache` with hit counters. No iOS integration yet.

Changes
- Backend
  - `translateMessage` HTTPS endpoint (SSE headers) with request validation.
  - Helpers: `checkCache(text)`, `storeInCache(text, translations)`; update `metadata.hitCount/lastUsed`.
  - Env/config: `OPENAI_API_KEY`, `MAX_CONTEXT_MESSAGES` (default 10), `CACHE_TTL_DAYS`.
  - Guard by `AI_TRANSLATION_ENABLED`.
  - Reuse existing app rate‑limiting structure to keep costs low.
  - Auth: require Firebase ID token on requests; verify token in Function.
  - Streaming: send SSE events as token deltas (`type: "delta"`) and a final (`type: "final"`) message.
- Data
  - Create `translationCache` collection keyed by `textHash` (doc: `translations`, `metadata`).
  - Add composite index on `messages(conversationId asc, timestamp desc)` for context fetch.

Tests
- Function unit tests/mocks: cache hit/miss path; SSE response format; config guards.

Acceptance
- Function deploys; returns cached result when available; streams non‑cached response; does nothing when disabled.

Setup/Deploy
- Firebase Functions: set config `OPENAI_API_KEY`, `AI_TRANSLATION_ENABLED=true`, `MAX_CONTEXT_MESSAGES=10`, `CACHE_TTL_DAYS=30`.
- Deploy functions: `firebase deploy --only functions`.
- Firestore: ensure `translationCache` rules allow read for verified users and writes from Functions.
- Add Firestore composite index: `messages(conversationId asc, timestamp desc)`.

---

### PR 03 – Firestore onCreate Auto‑Translate Trigger (All New Messages)
Summary
- Adds `onMessageCreate` trigger to populate `versions.{en,ka,original}` for all newly created messages (sent or received) if missing, reusing caching helpers. No historical backfill.

Changes
- Backend
  - Firestore trigger for `messages/{messageId}`: detect original language (stub), context fetch (stub), translate, update `versions` and `metadata.translatedAt`.
  - Reuse `checkCache/storeInCache`.
  - Feature‑flag protected.

Tests
- Trigger tests: skip when versions complete; update when missing; cache usage.

Acceptance
- New messages without both versions are populated server‑side; existing flows unaffected when flag OFF.
- Performance & SLO: p95 translation completion <8s; cache hits <2s.

Setup/Deploy
- Deploy updated trigger: `firebase deploy --only functions:onMessageCreate`.
- Verify Firestore security rules permit trigger updates to `messages/{messageId}.versions` and `metadata.translatedAt`.

---

### PR 04 – iOS Translation Transport: SSE Client + Eager Translate On Send
Summary
- Introduces `TranslationTransport` SSE client that requests translations from the Function and routes responses by `messageId`. Also triggers an eager translation request immediately upon send to minimize perceived latency. No UI changes.

Changes
- iOS
  - Add `TranslationTransport` (SSE‑only) with `requestTranslation(messageId:text:conversationId:completion:)`.
  - Integrate local SwiftData cache check before network request; store on success.
  - Hook into message send pipeline to eagerly translate and write `versions` when available; server trigger remains source of truth.
  - Error handling + retry policy (basic backoff).
  - Streaming: accumulate `delta` events into a buffer; invoke completion on `final`. UI may still wait for `final` before reveal.
- Config
  - Base URL/endpoint config.

Tests
- Unit tests with mocked transport: request flow, cache hit path, retry on failure.

Acceptance
- Manager callable from view models; no UI; safe when flag OFF.
- Performance & SLO: cache-hit delivery <2s; resilient retries within total <8s.

Setup/Deploy
- iOS: Add `TRANSLATE_FUNCTION_URL` to config (e.g., Remote Config or Info.plist) pointing to the HTTPS Function.
- Ensure Firebase Auth integration to get ID token; send `Authorization: Bearer <ID_TOKEN>` header in SSE request.

---

### PR 05 – UI: Double‑Tap Translation Reveal in Message Bubble + Contextual Menu
Summary
- Adds double‑tap gesture to expand/collapse translated view with loading and haptics. Adds contextual menu actions: “Show Translation”, “Explain Slang/Idioms”, “Adjust Tone → Formal/Casual”, “Cultural Context Hint”. Falls back gracefully if transport disabled.

Changes
- iOS UI
  - Update `MessageBubbleView`: collapsed vs expanded states; 300ms spring animation; 🇺🇸/🇬🇪 rows; divider and styling.
  - On double‑tap: if versions incomplete → call `TranslationTransport`; otherwise toggle.
  - Loading/failed states; light haptic on reveal.
  - Prepare architecture to support a future “language learning” toggle (show both / hide one / raw text).
  - Add long‑press/context menu with NL actions routing to LLM via transport.

Tests
- Snapshot/UI tests for collapsed/expanded/loading.
- Interaction tests for double‑tap toggling.

Acceptance
- Double‑tap reveals translations when available; no crashes with flag OFF.
- UI/UX: contextual menu present; clear loading and error states; animation ~300ms.

Setup/Deploy
- No backend changes. Ensure Remote Config `aiTranslation.enabled` can be toggled ON in staging for testing.

---

### PR 06 – LLM Integration: OpenAI GPT‑4o, Context (RAG‑Lite), Mixed‑Language Segmentation, NL Commands
Summary
- Wires actual LLM calls with a strict system prompt, language detection tool, recent‑messages context, mixed‑language segmentation, and natural language command handlers using OpenAI GPT‑4o.

Changes
- Backend
  - Implement `translateWithOpenAI` with consistent output shape.
  - Language detection helper and confidence score; segment text by language where applicable and translate per segment (preserve emojis/URLs/formatting), then merge.
  - Context fetch: last N messages of conversation (configurable, default 10); prompt assembly.
  - Respect rate limits; structured errors.
  - NL command router using OpenAI tool/function calling: intents [explain_slang, adjust_tone(formal|casual), cultural_hint, detect_language].
  - Return structured payloads for each command; cache frequent explanations where safe.

Tests
- Unit tests against mocked LLM client: prompt format, fallback, mixed language handling.

 Acceptance
- Live translation works end‑to‑end with cache miss; prompt rules enforced.
  - Mixed‑language inputs are segmented and translated appropriately (Georgian → EN only parts; embedded EN in KA rendered to KA as well).
  - NL commands achieve ≥90% success on curated test prompts; simple cached commands respond <2s.

Setup/Deploy
- Confirm `OPENAI_API_KEY` in Functions config and adequate quota.
- Update and deploy Functions with NL command routes.
- If needed, add Remote Config for toggling NL menu items separately (e.g., `aiTranslation.nlActions.enabled`).

---

### PR 07 – Analytics, Telemetry, and Quality Signals
Summary
- Adds analytics for translation completion, latency, cache hit, and optional user quality ratings.

Changes
- iOS
  - `TranslationAnalytics.logTranslationCompleted(messageId, latency, cached)`.
  - Optional rating action surface (non‑blocking).
- Backend
  - Structured logs for cache hits/misses, latency, error categories.
  - Metrics for NL command success rate and response times; track p95 and cache hit rates.

Tests
- Unit tests ensure analytics events fired; backend logs contain expected fields.

Acceptance
- Events appear in analytics; no PII beyond IDs/metrics.
 - Dashboards show p95 latency (<8s translations, <15s agents) and NL command success ≥90% on test set.

Setup/Deploy
- Ensure Firebase Analytics is initialized; create dashboards/BigQuery export if available.
- Add debug view testing for new events.

---

### PR 08 – Hardening: Error States, Timeouts, Retries, Feature Flag Controls, Rate Limiting, Performance Tuning
Summary
- Finalizes reliability: timeouts, retry/backoff, user‑visible error state with retry, remote control via feature flags, reuse of existing app rate limiting, and performance tuning to meet targets.

Changes
- iOS
  - User‑friendly error surface in `MessageBubbleView`; retry action.
  - Transport timeouts and circuit‑breaker‑style backoff.
- Backend
  - Function timeouts, error mapping; partial result handling; guardrails.
  - Reuse existing app rate‑limiting structure for translation requests.
  - Tune context size and temperature for latency; fast‑path cache lookup; preemptive cancel on UI dismiss.
- Config
  - Remote toggles: enable/disable translation; adjust context length and thresholds.

Tests
- Transport timeout/retry tests; UI retry flow; backend timeout handling.

Acceptance
- Graceful degradation on failures; quick disable via flags.
 - p95 SLOs met in staging: <8s translations, <15s agent commands; cache-hit <2s.

Setup/Deploy
- Remote Config: add knobs (`aiTranslation.context.maxMessages`, `aiTranslation.transport.timeoutMs`, etc.).
- Staging load test: run scripted E2E to validate SLOs; adjust config accordingly.

---

### PR 09 – End‑to‑End Tests and Docs
Summary
- Adds E2E tests across cache hit/miss, UI reveal, and trigger translation; minimal ops docs and runbooks.

Changes
- Tests
  - E2E happy path: send message → trigger populates versions → UI double‑tap shows both lines.
  - Cache hit path: same text returns instantly from local/Firestore cache.
  - Failure path: LLM failure → error state → retry succeeds.
- Docs
  - Setup steps (keys, env, deployment), feature flag operations, troubleshooting.
  - Tooling instructions: enabling SSE endpoint, creating Firestore composite index, setting `OPENAI_API_KEY`, Remote Config flag, and rate‑limit config.

Acceptance
- E2E suite passes locally/CI; docs enable new dev to run feature.

---

Implementation Notes (Self‑Containment)
- Every PR compiles and runs with `aiTranslation.enabled` OFF; no user‑visible regression.
- New code paths are behind guards; stubs/mocks are included where later PRs will fill in.
- Each PR includes its own tests; later PRs may add more but do not break previous ones.
- SSE‑only transport. Auto‑translate all new messages. No backfill. No current opt‑out; future language‑learning toggle planned.

Setup Instructions (Summary)
- Firebase Functions config: set `OPENAI_API_KEY`, `AI_TRANSLATION_ENABLED=true`, `MAX_CONTEXT_MESSAGES=10`, `CACHE_TTL_DAYS=30`.
- Firestore index: create composite index on `messages(conversationId asc, timestamp desc)`.
- iOS: enable Remote Config flag; add endpoint base URL; ensure authenticated requests include Firebase ID token.
- CI/CD: provide `OPENAI_API_KEY` secret; deploy Functions and Firestore indexes before running E2E tests.
 - Rules: confirm Firestore rules allow Functions to write `translationCache` and update message `versions`/`metadata`.


