---
id: local-model-integration
status: in_progress
owner: larsboes
source_of_truth: true
related:
  machnotch_prd: Plans/PRDs/machNotch.md
  machbrief_macos_prd: Plans/PRDs/machBrief-macOS.md
  machbrief_ios_prd: Plans/PRDs/machBrief-iOS.md
  architecture: docs/Architecture.md
  plugin_system: docs/Architecture.md
  bazel_roadmap: docs/Roadmap.md
  repo_manifest: repo.yaml
last_updated: 2026-06-13
---

# Local Model Integration Plan — mach-mono

**Goal:** Build a first-class, local-first inference stack for the mach-mono suite — combining Apple FoundationModels (built-in, zero-config) with oMLX (advanced local MLX server for larger/specialized models) under the existing 3-tier `AIProvider` / `AITextGenerationService` / `ProviderBackedAIService` architecture. Privacy by default. Streaming everywhere. No mandatory cloud, no mandatory third-party install.

**Scope:** `Apps/machNotch` (macOS), `Apps/machBrief` (macOS + iOS in v2), `Packages/MachBriefKit`, `Packages/NotchServices`, and `Packages/MachIntelligenceKit`. Apps consume AI through service contracts rather than constructing providers directly.

**Status:** Milestones M0, M1, M2, and M3 are effectively landed, but the implementation lives in `Packages/NotchServices/Sources/NotchServices/Plugins/AI/`, not in `Packages/MachIntelligenceKit`. `MachIntelligenceKit` currently owns the shared embedding/transcription contracts. Next implementation session starts with M4 (Embeddings + Shelf Semantic Search), after keeping this package split explicit.

**Current code reality (2026-06-13):**

- Text generation providers live in `Packages/NotchServices/Sources/NotchServices/Plugins/AI/`.
- `FoundationModelsProvider`, `OMLXProvider`, streaming support, provider-backed services, and `AITextGenerationServiceFactory` are in `NotchServices`.
- `Packages/MachIntelligenceKit` is intentionally small today: `AIEmbeddingService` and `AITranscriptionService` contracts plus tests.
- Do not migrate providers into `MachIntelligenceKit` as a drive-by cleanup. Either keep the split and update this plan, or schedule a dedicated migration milestone with Bazel/package boundary changes.

---

## Before Implementation — Repo Health Gate

Before starting this local-model integration, finish or explicitly defer the current
repo-health items from `Analysis.md`:

- **Land the CI-signal slice first:** test result artifacts, LCOV coverage artifact,
  `skills-check`, `tools/sync-skills.sh --check`, and the MachBriefKit deterministic-cache
  test fix are implemented in the current working tree and locally verified.
- **Keep SDK drift visible:** local Bazel verification still needs
  `--macos_sdk_version=$(xcrun --sdk macosx --show-sdk-version)` on SDK 26.5; do not fold
  an SDK policy change into the AI integration unless builds start failing again.
- **Done before the next release:** the release publish job updates the issue-form
  version dropdown inline on `main`; the standalone updater is manual-only.
- **Done before wider distribution:** dependency review covers PR dependency
  changes, main/manual runs export the GitHub dependency graph SBOM artifact,
  and Bazel/release source-of-truth links are documented in ADR 0009.

---

## 0. Non-Goals

- **Not a cloud-AI plan.** No OpenAI/Anthropic/Gemini wiring in the default path. OpenAI/Anthropic-compatible APIs are acceptable only for explicitly configured localhost providers such as oMLX.
- **Not a replacement for FoundationModels.** FM remains the default text generator on macOS 26+ for the cases it handles well (summarize, rewrite, extract).
- **Not bundling weights.** oMLX manages/downloads advanced model files outside the app. mach-mono does not bundle model weights.
- **No GPL/MPL dependencies.** Per `docs/decisions/0003-license-policy.md`. oMLX is Apache 2.0; model licenses still need per-model review.
- **No telemetry on inference.** Local-only. Zero usage data leaves the device by default.
- **No Ollama support.** `OllamaProvider` has been removed; do not reintroduce Ollama settings, onboarding, docs, or feature work.
- **iOS advanced-model integration is v2.** macOS-first. iOS gets FoundationModels-only in v1 (`Plans/PRDs/machBrief-iOS.md`).

---

## 1. Why Local-First, Why Foundation Models + oMLX

**Privacy.** Notch content, clipboard, calendar, and brief-stream text are intimate. None should leave the device.

**Latency.** A teleprompter that waits 2s on a cloud round-trip is unusable. A local 7B model on Apple Silicon delivers first-token latency under 200ms.

**Cost.** Zero marginal cost per generation enables ambient features (every clipboard event, every notification, every word reveal) that would be prohibitive at cloud rates.

**Foundation Models first.** Apple’s `FoundationModels` framework is the default text path on macOS 26+: zero install, on-device, private, and designed for the rewrite/summarize/extract tasks mach.notch needs.

**Why oMLX in addition to Foundation Models.** Foundation Models does not yet cover every advanced/power-user need: larger/specialized local models, embeddings/rerankers, multimodal models, OpenAI/Anthropic-compatible localhost APIs, and reuse of existing MLX-format model directories. oMLX fills that role without making mach-mono embed or sign MLX runtime internals.

**Verified API posture (SDK 26.5):** `SystemLanguageModel.default.availability` reports `.available` or `.unavailable(.deviceNotEligible | .appleIntelligenceNotEnabled | .modelNotReady)`. `LanguageModelSession.respond(...)` returns `Response<String>.content`. `LanguageModelSession.streamResponse(...)` yields partial snapshots, so providers must emit deltas or intentionally replace accumulated text. `GenerationOptions` supports `sampling`, `temperature`, and `maximumResponseTokens`; provider-specific stop sequences are ignored for Foundation Models.

---

## 2. Provider Capability Matrix

| Capability | FoundationModels | oMLX (advanced local) |
|---|---|---|
| **Availability** | macOS 26+ Apple Silicon | macOS 15+ Apple Silicon, external local app/server |
| **Setup cost** | None | User installs oMLX and chooses/downloads models |
| **Model size sweet spot** | Apple on-device model | MLX-format LLM/VLM/embedding/reranker models |
| **Streaming** | Yes (`LanguageModelSession.streamResponse`) | Yes via local OpenAI/Anthropic-compatible streaming APIs |
| **Structured generation** | Yes (`@Generable`) | Via JSON/tool formats exposed by oMLX-compatible APIs |
| **Embeddings** | No (today) | Yes, if model/server exposes embeddings |
| **ASR / Whisper** | No (use `SFSpeechRecognizer` initially) | Defer until oMLX/adjacent local ASR path is chosen |
| **Vision / multimodal** | Limited | Yes, depending on local model |
| **License posture** | First-party | Apache 2.0 app/runtime + per-model license review |
| **Default in mach-mono** | ✅ Primary (text) | ✅ Advanced opt-in |

**Selection rule:**

1. If a `FoundationModels` model handles the task and `macOS ≥ 26`: use it.
2. Else if the user explicitly enables/configures oMLX for an advanced local task: route to oMLX.
3. Else: return `NoAITextGenerationService` deterministic fallback — feature cleanly absent in UI.

---

## 3. Model Survey & Recommended Picks

### 3.1 Chat / Instruction Models (oMLX advanced runtime)

| Model | Params | Quant | RAM @ runtime | First-token p50 (M2) | License | Recommended use |
|---|---|---|---|---|---|---|
| **Llama 3.2 1B Instruct** | 1.2B | Q4 | ~1.0 GB | ~80 ms | Llama Community (commercial OK) | 8GB Macs, Notifications digest, Calendar brief |
| **Llama 3.1 8B Instruct** | 8B | Q4 | ~5.0 GB | ~180 ms | Llama Community | Advanced opt-in only, explicit license note |
| **Qwen 2.5 7B Instruct** | 7B | Q4 | ~4.8 GB | ~170 ms | Apache 2.0 | Cleanest licensing alternative to Llama |
| **Phi-3.5 mini Instruct** | 3.8B | Q4 | ~2.4 GB | ~120 ms | MIT | Best 8GB compromise — solid quality, MIT |
| **Gemma 2 2B Instruct** | 2B | Q4 | ~1.5 GB | ~95 ms | Gemma terms (commercial OK) | Lightweight Clipboard intent classification |

**Default chat path:** Foundation Models. Do not download or bundle a chat model in mach-mono by default.

**Advanced oMLX picks:** Prefer Apache/MIT-friendly models exposed through the user's local oMLX server. Qwen-family models are the clean licensing default for advanced text generation; keep Llama-family models opt-in with explicit license notes.

### 3.2 Embedding Models (oMLX advanced runtime)

| Model | Dims | Size | License | Recommended use |
|---|---|---|---|---|
| **bge-small-en-v1.5** | 384 | 130 MB | MIT | First oMLX-backed Shelf semantic search candidate |
| **bge-m3** | 1024 | 2.3 GB | MIT | Multilingual users, opt-in |
| **nomic-embed-text-v1.5** | 768 | 550 MB | Apache 2.0 | Alternative — slightly better English benchmark |

**Default embedding pick:** none in mach-mono v1. Use oMLX embeddings only after the user enables the advanced local provider. Recommended first model remains `bge-small-en-v1.5` for size/license fit.

### 3.3 ASR Models (deferred)

| Model | Size | Realtime factor (M2) | Use case |
|---|---|---|---|
| **whisper-tiny.en** | 75 MB | ~0.05× | Real-time teleprompter Flow Mode (Phase 10.2) |
| **whisper-base.en** | 145 MB | ~0.10× | Voice notes transcription |
| **whisper-small.en** | 460 MB | ~0.20× | Quality-first transcription, batch only |
| **Parakeet TDT 0.6B** | 600 MB | ~0.05× | If MLX port stabilizes; lowest WER for English |

**Default ASR pick:** defer. Teleprompter Flow Mode should keep the current speech path until a specific local ASR backend is selected. Do not pull ASR into the Foundation Models/oMLX provider work unless it is explicitly scoped.

### 3.4 Memory Budget by Apple Silicon Tier

| Mac config | Available for AI | Allowed defaults | Allowed opt-ins |
|---|---|---|---|
| 8 GB unified | ~3 GB | Foundation Models only | oMLX not recommended |
| 16 GB unified | ~6 GB | Foundation Models | oMLX small/medium models |
| 24 GB unified | ~10 GB | Foundation Models | oMLX 7B-class models + embeddings |
| 32 GB+ unified | ~14 GB+ | Foundation Models | larger oMLX models at user discretion |

`MachIntelligenceKit` should read `ProcessInfo.processInfo.physicalMemory` to decide whether to offer oMLX features and warn users before connecting to heavyweight local models. oMLX owns model loading/eviction; mach-mono does not enforce a model store in v1.

### 3.5 Quantization Strategy

- **Foundation Models:** no app-managed quantization.
- **oMLX:** model quantization is selected/managed by oMLX and the user's installed model. mach-mono should display model/provider metadata when available, not own quantization policy.
- **Future native MLX:** direct MLX-Swift integration is out of the next-session path. Reconsider only if oMLX cannot cover required local capabilities.

---

## 4. Architecture

### 4.1 New Package — `Packages/MachIntelligenceKit`

**License:** MIT (matches `MachBriefKit`, `MacroVisionKit`).

**Why a separate package:** houses cross-app AI contracts and provider-neutral helpers without dragging concrete app/plugin code into packages. It starts dependency-free; oMLX/Foundation Models adapters can be added behind app/platform-specific targets later.

**Path:** `Packages/MachIntelligenceKit/`

```
Packages/MachIntelligenceKit/
├── Package.swift                                  # SPM shim, Bazel-fed
├── BUILD.bazel                                    # canonical
├── Sources/MachIntelligenceKit/
│   └── Protocols/
│       ├── AIEmbeddingService.swift              # NEW
│       └── AITranscriptionService.swift          # NEW
├── Tests/MachIntelligenceKitTests/
│   └── MachIntelligenceKitTests.swift
```

### 4.2 External Provider — oMLX

- **Site:** `https://omlx.ai/`
- **Repo:** `https://github.com/jundot/omlx`
- **License:** Apache 2.0
- **Runtime posture:** external local macOS app/server, not bundled into mach-mono. Requires macOS 15+, Apple Silicon, and Python 3.10+ for source installs; 16 GB RAM is the documented minimum and 64 GB+ is recommended for larger models.
- **API posture:** connect over localhost using oMLX's OpenAI-compatible API rooted at `http://localhost:8000/v1` by default. Confirmed endpoints: `POST /v1/chat/completions`, `POST /v1/completions`, `POST /v1/embeddings`, `POST /v1/rerank`, and `GET /v1/models`. Anthropic-compatible support can be considered later, but the first provider should use one wire shape.
- **Bazel:** no MLX-Swift dependency in the next-session path. Keep `MachIntelligenceKit` dependency-free until a direct native MLX integration is explicitly chosen.

### 4.3 Extended Contracts in the Existing AI Stack

The existing 3-tier stack lives in `Packages/NotchServices/Sources/NotchServices/Plugins/AI/`. `MachIntelligenceKit` is the home for cross-app modality contracts that are not tied to plugin service wiring. Apps continue to consume `any AITextGenerationService` via the service container / object graph, not by constructing providers directly.

**Streaming — extend `AIProvider`:**

```swift
protocol AIProvider: Sendable {
    var id: String { get }
    var name: String { get }
    var isAvailable: Bool { get async }

    func generate(prompt: String, config: AIGenerationConfig) async throws -> String

    // NEW — default impl yields one chunk for non-streaming providers.
    func generateStream(prompt: String, config: AIGenerationConfig)
        -> AsyncThrowingStream<String, Error>
}

extension AIProvider {
    func generateStream(prompt: String, config: AIGenerationConfig)
        -> AsyncThrowingStream<String, Error>
    {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let full = try await generate(prompt: prompt, config: config)
                    continuation.yield(full)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
```

This is backward-compatible — FoundationModels and oMLX providers gain streaming; existing call sites keep working.

**Embeddings — new protocol:**

```swift
protocol AIEmbeddingService: Sendable {
    var dimension: Int { get }
    var isAvailable: Bool { get async }
    func embed(_ text: String) async throws -> [Float]
    func embedBatch(_ texts: [String]) async throws -> [[Float]]
}
```

**Transcription — new protocol:**

```swift
protocol AITranscriptionService: Sendable {
    var isAvailable: Bool { get async }
    func transcribe(_ audioURL: URL) async throws -> TranscriptionResult

    // Live streaming variant for Teleprompter Flow Mode.
    func transcribeStream(_ audio: AsyncStream<Data>)
        -> AsyncThrowingStream<TranscriptionPartial, Error>
}

struct TranscriptionResult: Sendable {
    let text: String
    let segments: [TranscriptionSegment]
    let language: String
}
```

### 4.4 Provider Metadata & Model Ownership

mach-mono does **not** own a model registry, manifest, downloader, or on-disk weight layout in the Foundation Models/oMLX path.

**Foundation Models:** availability and model lifecycle are owned by macOS. mach-mono asks `SystemLanguageModel` whether the default model is available and degrades cleanly when it is not.

**oMLX:** model installation, quantization, storage, and updates are owned by the user's local oMLX setup. mach-mono stores only provider settings:

```swift
struct OMLXProviderSettings: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var host: URL                         // default http://127.0.0.1:8000
    var preferredModelId: String?
    var allowNonLocalhostHost: Bool       // false by default
}
```

If oMLX exposes model metadata, mach-mono may cache a short-lived view model for display only:

```swift
struct LocalAIModelInfo: Equatable, Sendable {
    var id: String
    var capabilities: Set<Capability>     // text, embeddings, vision, rerank, etc.
    var contextWindow: Int?
    var licenseSummary: String?
}
```

No model file paths, checksums, or download state are stored by mach-mono in M1/M2.

### 4.5 ServiceContainer Wiring

`Apps/machNotch/machNotch/Plugins/Services/System/ServiceContainer.swift` currently exposes `let ai: any AITextGenerationService`. Extend to:

```swift
public let ai: any AITextGenerationService            // existing
public let embeddings: any AIEmbeddingService         // NEW
public let transcription: any AITranscriptionService  // NEW
```

`AppObjectGraph` constructs them via a new `AISubsystemFactory` that owns provider selection:

```swift
let factory = AISubsystemFactory(
    settings: settings,
    intelligence: MachIntelligence(rootDir: appSupportModelsDir)
)
self.ai            = factory.makeTextService()
self.embeddings    = factory.makeEmbeddingService()
self.transcription = factory.makeTranscriptionService()
```

`AIManager` is renamed/upgraded to support Foundation Models plus oMLX-backed advanced local modalities; the old Ollama provider has been removed (Phase 11.6 prerequisite — see §6.1).

### 4.6 Concurrency Discipline

- `FoundationModelsProvider` should wrap `LanguageModelSession` for zero-config text generation.
- `OMLXProvider` should be a `Sendable` transport client for the local oMLX server, not an embedded inference runtime.
- `ProviderBackedAIService` stays `@MainActor` but `await`s all provider calls — no UI block.
- Streaming uses `AsyncThrowingStream` so SwiftUI can render token-by-token without blocking.

---

## 5. Integration Points

### 5.1 machNotch — TeleprompterPlugin

Replaces the current legacy/local-provider `aiAssist` (`Apps/machNotch/machNotch/Plugins/BuiltIn/TeleprompterPlugin/TeleprompterState.swift:146`) with the streaming `AITextGenerationService`:

- AI-assisted rewrite renders tokens incrementally in `TeleprompterExpandedView`.
- Flow Mode (`Plans/PRDs/machNotch.md` §10.2) keeps the current speech path until local ASR is separately selected.
- `TeleprompterAIAction` enum gains the Phase 11.4 actions (expandBullets, simplify, addPauses, translateStyle, timeToTarget) — implemented as prompts in `ProviderBackedAIService`.

### 5.2 machNotch — ClipboardPlugin

- Live intent classification uses Foundation Models first. oMLX may handle specialized classification only when the user explicitly enables an advanced local model.
- Action extraction on long-text clipboards: "extract action items" → bullet list rendered in expanded panel.
- All inference on a background actor; UI never blocks even on slow first-token.

### 5.3 machNotch — NotificationsPlugin

- Notification burst digest: when ≥3 notifications arrive within 60s, run a single Foundation Models summarize call with strict 64-token cap → display a "3 messages: …" rolled-up card. Use oMLX only if the user explicitly enabled it for advanced local AI.
- Embedding-based deduplication: hash near-identical notifications via embeddings (cosine similarity > 0.92) so Slack DMs aren't shown three times.

### 5.4 machNotch — CalendarPlugin

- "Next meeting" 1-sentence brief: combine attendees + description + agenda doc (if linked) → 1-line spoken brief 5 minutes before the meeting.
- Implemented as a `MeetingBriefService` that calls `ai.draftIntro(topic:, durationSeconds:)`-style API.

### 5.5 machNotch — DisplaySurfacePlugin

- The Local API `POST /api/v1/display/text` endpoint (`Plans/PRDs/machNotch.md` §6/§6b) gains an opt-in `compress: true` parameter — text longer than the notch can display is compressed via `ai.summarize(maxTokens: 32)` before render.
- For long terminal output piped into the notch ("build progress"), summarize streaming so the user sees rolling status without waiting for completion.

### 5.6 machNotch — ShelfPlugin

- Semantic search across all shelf items by name + extracted file text (PDFs, txt, code). Indexed via a configured oMLX embedding model such as `bge-small-en-v1.5` → `SQLiteVecIndex` for ≥10k items, in-memory HNSW under.
- New keyboard shortcut "find anything" opens a search field in the expanded panel; types a query → top 5 matches in <50ms.

### 5.7 machBrief — MoodCheckInSource (v2)

- Mood AI (already on machBrief v2 ideas list): use embeddings to cluster mood notes over time, then summarize patterns weekly. Output as a brief entry on Sunday evening: "this week you felt good on focus days, low on meeting-heavy days."

### 5.8 machBrief — WordSource enrichment

- When the bundled definition is missing or thin, optional Foundation Models rewrite produces a memorable example sentence. oMLX can be used instead only when explicitly enabled. User-toggleable; off by default.

### 5.9 Local HTTP API

Expose at `127.0.0.1:19384` (existing `LocalAPIServer`):

| Endpoint | Body | Purpose |
|---|---|---|
| `POST /api/v1/ai/generate` | `{prompt, config?}` | Non-streaming generate |
| `POST /api/v1/ai/stream` | `{prompt, config?}` | SSE stream of tokens |
| `POST /api/v1/ai/embed` | `{texts: […]}` | Returns vectors |
| `POST /api/v1/ai/transcribe` | multipart audio | Returns transcript |
| `GET /api/v1/ai/models` | — | Lists available provider/model metadata when exposed by Foundation Models or oMLX |

Auth: localhost-only by default (per `Plans/PRDs/machNotch.md` §8 LocalAPIConfig). Same posture as existing routes. mach-mono does not expose a model download endpoint in the Foundation Models/oMLX path; oMLX owns advanced model installation and storage.

---

## 6. Infrastructure & Code Debt

### 6.1 Phase 11.6 is a hard prerequisite

The old local provider path made provider selection ambiguous the moment a second provider existed. **Done:** Ollama support is removed, Foundation Models is the default local text provider, and oMLX is the only advanced explicit provider.

### 6.2 `AIProvider` lacks streaming

`Packages/NotchServices/Sources/NotchServices/Plugins/AI/AIProvider.swift` owns provider generation and streaming. Keep new text-generation provider work in `NotchServices` unless a dedicated migration moves the full AI service stack.

### 6.3 `AITextGenerationService` is `@MainActor`

`Packages/NotchServices/Sources/NotchServices/Plugins/AI/AITextGenerationService.swift` is the plugin/app-facing text contract. For Foundation Models and oMLX this is fine because heavy lifting happens in Apple's framework or the local oMLX server. Resolution:

1. Keep the public `AITextGenerationService` `@MainActor` (it's the API surface plugins use).
2. Provider implementations must `await` framework/network calls so the main actor yields between suspension points.
3. Streaming via `AsyncThrowingStream` makes this seamless.

No protocol change. Just disciplined implementation.

### 6.4 `isAvailable` sync/async mismatch

`AIProvider.isAvailable` is `var isAvailable: Bool { get async }` — async, requires await. `ProviderBackedAIService.isAvailable` is sync (`var isAvailable: Bool { true }`). Plugins reading `service.isAvailable` get a misleading constant `true`. Fix: make `AITextGenerationService.isAvailable` async too, OR cache the last-known async value in the service with a `refresh()` method. Recommend: async — single source of truth, callers `await` it once at plugin activation.

### 6.5 No embeddings infrastructure

No vector index exists today. Plan adds:

- `AIEmbeddingService` protocol (§4.3) exists.
- `OMLXEmbeddingProvider` should call the configured local oMLX embedding endpoint when enabled.
- Vector indexing (`VectorIndex` / `SQLiteVecIndex`) remains a later Shelf/search feature and should not block Foundation Models text generation.

### 6.6 No model lifecycle

There is currently no UI or service for selecting an advanced local provider. For the oMLX path, mach-mono should not download, update, or delete model weights. Plan adds:

- `OMLXProviderSettings` (enabled, host, preferred model id if needed)
- `OMLXHealthCheck` / provider availability check against localhost
- Optional model metadata display if oMLX exposes installed models
- No model weight storage in mach-mono v1

### 6.7 Bazel + AI providers

`docs/Roadmap.md` is currently at Phase 3/4. Next-session AI work requires:

- Add `bazel test //Packages/MachIntelligenceKit:MachIntelligenceKitTests` to CI matrix.
- Add any Foundation Models / oMLX provider files to the `NotchServices` Bazel target.
- No new MLX-Swift / dylib signing work is required for the oMLX local-server path.

### 6.8 Privacy & permissions

Establish written policy in this plan, then enforce in code:

- AI features are per-plugin opt-in. Default state: off. First-launch onboarding shows what each feature does.
- Zero telemetry from `MachIntelligenceKit`. No anonymous usage stats. No remote error reporting.
- oMLX communication is localhost-only by default.
- No cloud fallback is silently inserted. If Foundation Models or oMLX fails, behavior is `NoAITextGenerationService` (clean absence), never a cloud call.
- Settings UI shows provider availability and configured local host. Model/RAM details are displayed only if oMLX exposes them.

### 6.9 `Package.swift` is a Bazel-feeding shim

`Package.swift` at repo root says `products: []` — it exists only so `rules_swift_package_manager` can resolve deps. The next-session Foundation Models/oMLX path does **not** require adding `mlx-swift`.

If direct native MLX-Swift integration is revived later, create a separate spike and update this plan before changing package dependencies.

---

## 7. Phased Delivery

Each milestone has explicit acceptance criteria. No milestone closes until all criteria pass `bazel build` + `bazel test` + manual smoke.

### M0 — Foundation & Contracts (landed in `17fc3ca`)

**Goal:** Land the contracts and clean up the AI stack so Foundation Models and oMLX can plug in without provider ambiguity.

**Work:**
- Phase 11.6 refactor: remove legacy Ollama provider support.
- Add `generateStream` to `AIProvider` with default impl (§4.3).
- Add `AIEmbeddingService` + `AITranscriptionService` protocols.
- Make `AITextGenerationService.isAvailable` async (§6.4).
- Create empty `Packages/MachIntelligenceKit` skeleton (no MLX yet) + `BUILD.bazel`.
- Add `MachIntelligenceKit` to `repo.yaml` under `packages.planned → existing`.

**Acceptance:**
- `bazel build //Apps/machNotch:machNotch` green.
- `bazel test //Apps/machNotch:machNotchTests //Packages/MachBriefKit:MachBriefKitTests //Packages/MachIntelligenceKit:MachIntelligenceKitTests` green.
- `AIManager()` creates with zero providers registered; AI features cleanly absent.
- CI green on `main`.

### M1 — FoundationModelsProvider (Completed)

**Goal:** First zero-config text generation working end-to-end behind `AITextGenerationService`.

**Work:**
- **Completed**: Implement `FoundationModelsProvider` in the existing app AI stack.
- **Completed**: Use `LanguageModelSession` for `generate` and `streamResponse` for `generateStream`.
- **Completed**: Map `AIGenerationConfig.temperature` and `maxTokens` to `GenerationOptions.temperature` and `maximumResponseTokens`; ignore `stopSequences` because Foundation Models has no equivalent option.
- **Completed**: Convert streaming partial snapshots into text deltas before yielding to `AIProvider.generateStream`.
- **Completed**: Wire `AIManager` default registration to Foundation Models when available; otherwise remain cleanly absent.
- **Completed**: Update teleprompter AI action visibility to reflect async provider availability.

**Acceptance:**
- Fresh install on macOS 26+ with Apple Intelligence available: Teleprompter refine/summarize/intro works with no external app installed.
- On unsupported/unavailable systems, AI actions remain cleanly absent with no install messaging.
- Existing M0 tests still pass, plus provider tests for availability and prompt forwarding where testable.

### M2 — oMLX Advanced Local Provider (Completed)

**Goal:** Let power users route advanced local generation/embeddings to an explicitly configured oMLX localhost server.

**Work:**
- **Completed**: Implement `OMLXProvider` as an OpenAI-compatible localhost client.
- **Completed**: Add advanced provider settings: enabled, host (default `http://127.0.0.1:8000`), optional model id.
- **Completed**: Add health/model check using oMLX endpoints; do not start/stop or install oMLX from mach-mono.
- **Completed**: Wire selection rule: Foundation Models remains default; oMLX only takes priority when explicitly enabled and available.
- **Completed**: Keep Ollama removed; no settings or compatibility path.

**Acceptance:**
- With oMLX running locally, advanced provider availability turns true and generation works through `AITextGenerationService`.
- With oMLX disabled/stopped, app falls back to Foundation Models or clean absence.
- No cloud endpoint is reachable by default.

### M3 — Streaming + Teleprompter Live UX (Completed)

**Goal:** Token-by-token rendering in user-visible flows.

**Work:**
- **Completed**: Implement streaming for `FoundationModelsProvider` and `OMLXProvider`.
- **Completed**: Add streaming variants to `AITextGenerationService` (rewriteStream, summarizeStream, draftIntroStream).
- **Completed**: Update `TeleprompterControlPanel` AI action handlers to consume the stream and render tokens live.
- **Completed**: Add `DisplaySurface` `compress: true` path.

**Acceptance:**
- Teleprompter "rewrite" shows tokens appearing within 300ms of click.
- `POST /api/v1/ai/stream` returns SSE that a `curl -N` consumer can read incrementally.
- No main-thread block over 16ms during generation (verify via Instruments).

### M4 — Embeddings + Shelf Semantic Search (oMLX-backed)

**Goal:** Embeddings infrastructure operational; first user-visible feature uses it.

**Work:**
- Implement `OMLXEmbeddingProvider` with a user-configured local embedding model.
- Implement `VectorIndex` (in-memory HNSW) and `SQLiteVecIndex`.
- Shelf indexer: extract text from added items (TXT/MD/PDF via PDFKit), embed, store.
- Shelf semantic search UI (Cmd-K palette in expanded panel).

**Acceptance:**
- 10k synthetic items: search query → top-5 results in <50ms.
- Index rebuilds incrementally when items added; no full re-index.
- Index persists across restart; verified by sha256 of vector blobs.

### M5 — Transcription + Teleprompter Flow Mode (deferred)

**Goal:** ASR-driven scroll speed working.

**Work:**
- Select a local ASR backend separately.
- Replace `SFSpeechRecognizer` path in `VoiceScrollEngine` only after the backend is proven — keep `SFSpeechRecognizer` as fallback.
- Notifications digest using same provider.

**Acceptance:**
- 60s of speech transcribed in <2s on M2.
- Flow Mode scroll lock-on to recognized words within 200ms.
- WER on test set ≤ 8% (whisper-base.en target).

### M6 — Cross-App, machBrief, Hardening (open-ended)

**Goal:** machBrief consumes the shared AI contracts and provider selection rules; rough edges removed.

**Work:**
- `machBrief` Mood AI clustering using embeddings.
- Optional `WordSource` enrichment.
- Battery-aware throttling (don't run inference at <20% on battery unless user opts in).

**Acceptance:**
- `machBrief` uses Foundation Models by default where available and oMLX only when explicitly configured.
- Weekly mood brief generates correctly on a test dataset.
- Battery-aware throttle measurably reduces inference rate at low battery.

---

## 8. Risk Register

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | Foundation Models availability varies by OS, hardware, locale, or Apple Intelligence state | Medium | AI appears absent on some machines | Async availability gate; clean absence; no install nags |
| 2 | oMLX is external and may not be installed/running | Medium | Advanced provider unavailable | Explicit opt-in, health check, fallback to Foundation Models or NoAI |
| 3 | User-configured oMLX model license is unclear | Low | Legal/compliance ambiguity | Do not bundle weights; show model/license metadata when oMLX exposes it; document that users own model selection |
| 4 | oMLX API changes or endpoint differences | Medium | Advanced provider breaks | Keep provider thin; isolate wire DTOs; test against documented localhost API |
| 5 | Concurrent FoundationModels + oMLX providers compete in `AIManager` | Medium | Wrong provider used | Deterministic selection rule: Foundation default, oMLX only when explicitly enabled |
| 6 | `@MainActor` UI freezes during generation | Medium | UX disaster | Await framework/network calls; streaming default; Instruments verification in M3 |
| 7 | Local provider points at a non-local endpoint | Medium | Privacy regression | Default localhost only; require explicit advanced override before any non-local host is accepted |
| 8 | Sparkle auto-update ships a new app version with mismatched provider settings | Low | Confusing errors | Keep provider settings schema small and backward compatible |
| 9 | Cloud-feature creep — someone adds an OpenAI provider "for testing" | Low | Privacy regression | Document non-goal §0 in `PLAN.md`; CODEOWNERS review for `Providers/` |
| 10 | Embedding index disk size explodes on power users | Medium | Disk pressure | Quantize embeddings to int8 in `SQLiteVecIndex`; expose "rebuild index" button |
| 11 | oMLX minimum OS/hardware excludes older Macs | Known | Advanced provider unavailable | App already targets macOS 26; use Foundation Models/NoAI fallback |
| 12 | Battery drain from background inference | Medium | User complaints | Battery-aware throttle in M5; never run inference proactively at <20% battery |

---

## 9. Dependency Sequencing

```
M0 (contracts, landed) ─► M1 (FoundationModelsProvider) ─► M2 (oMLX provider)
                                      │                         │
                                      └────────► M3 (streaming UX)
                                                                │
                                                                ├─► M4 (embeddings + Shelf search)
                                                                └─► M5 (ASR / Flow Mode, deferred)
```

**Hard ordering:**
1. M0 is landed; keep its clean-absence default.
2. M1 Foundation Models first — this is the product default.
3. M2 oMLX second — advanced local provider only after the default path works.
4. M3 streaming before embedding UX polish.
5. M5 ASR last — separate backend decision.

**Parallel-safe:** M2 oMLX provider and M3 streaming can be prototyped separately after M1, as long as provider selection semantics remain unchanged.

---

## 10. Open Questions

1. **Foundation Models availability API details.** Confirm exact `SystemLanguageModel` availability checks in the local SDK before implementation.
2. **oMLX wire shape.** First implementation should use OpenAI-compatible chat completions; confirm endpoint paths and streaming event shape against oMLX docs/source before coding.
3. **oMLX model discovery.** Decide whether Settings only asks for a model id, or reads installed models from oMLX if an endpoint exists. Recommended: start with manual model id + health check.
4. **Vector DB choice.** `sqlite-vec` is young (post-1.0 but recent). Alternative: pure-Swift FAISS port. Recommended: stick with sqlite-vec; revisit if it stalls.
5. **ASR backend.** Do not assume WhisperKit or MLX examples. Choose a backend only when Flow Mode returns to active scope.
6. **macOS <26 fallback for text generation.** If Foundation Models unavailable and oMLX disabled, feature stays absent. No install nag screen.

---

## 11. Appendix — File-by-File Footprint

| File | Change | Why |
|---|---|---|
| `Packages/NotchServices/Sources/NotchServices/Plugins/AI/AIManager.swift` | Registers and selects text providers | Provider selection |
| `Packages/NotchServices/Sources/NotchServices/Plugins/AI/AIProvider.swift` | Provider generation and streaming contract | Streaming |
| `Packages/NotchServices/Sources/NotchServices/Plugins/AI/AITextGenerationService.swift` | App/plugin-facing text service contract | API consistency |
| `Packages/NotchServices/Sources/NotchServices/Plugins/AI/ProviderBackedAIService.swift` | Provider-backed text-service implementation | Streaming UX |
| `Packages/NotchServices/Sources/NotchServices/Plugins/AI/FoundationModelsProvider.swift` | Default text provider where available | Zero-config AI |
| `Packages/NotchServices/Sources/NotchServices/Plugins/AI/OMLXProvider.swift` | Advanced local provider | Power-user local AI |
| `Apps/machNotch/machNotch/Plugins/Services/System/ServiceContainer.swift` | Wire Foundation Models default, oMLX explicit settings later | DI |
| `Apps/machNotch/machNotch/Plugins/Core/ServiceProviderProtocols.swift` | Mirror new fields in protocol | DI plumbing |
| `Apps/machNotch/machNotch/AppObjectGraph.swift` | Wire `AISubsystemFactory` | DI root |
| `Packages/MachIntelligenceKit/**` | Shared contracts only | Cross-app AI contracts |
| `repo.yaml` | Keep `MachIntelligenceKit` existing | Manifest truth |
| `Plans/PRDs/machNotch.md` | Phase 17 (or extend Phase 11) referencing this PLAN | Cross-link |
| `docs/Architecture.md` | New layer note: AI subsystem | Architecture truth |

---

## 12. References

- Existing AI stack: `Packages/NotchServices/Sources/NotchServices/Plugins/AI/{AIManager,AIProvider,FoundationModelsProvider,OMLXProvider,ProviderBackedAIService,NoAITextGenerationService,AITextGenerationService}.swift`
- Phase 11 plan: `Plans/PRDs/machNotch.md` §Phase 11 (lines 908–1147)
- Plugin architecture: `docs/Architecture.md`
- Architecture overview: `docs/Architecture.md`
- machBrief PRDs: `Plans/PRDs/machBrief-macOS.md`, `Plans/PRDs/machBrief-iOS.md`
- Bazel roadmap: `docs/Roadmap.md`
- Repo manifest: `repo.yaml`
- oMLX: https://omlx.ai/
- oMLX repo: https://github.com/jundot/omlx
- Apple Foundation Models: https://developer.apple.com/documentation/FoundationModels
- `LanguageModelSession`: https://developer.apple.com/documentation/foundationmodels/languagemodelsession
