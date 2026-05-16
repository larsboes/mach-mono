---
id: local-model-integration
status: planned
owner: larsboes
source_of_truth: true
related:
  machnotch_prd: docs/prds/machNotch.md
  machbrief_macos_prd: docs/prds/machBrief-macOS.md
  machbrief_ios_prd: docs/prds/machBrief-iOS.md
  architecture: docs/architecture/overview.md
  plugin_system: docs/architecture/plugin-system.md
  bazel_roadmap: docs/roadmaps/bazel.md
  repo_manifest: repo.yaml
last_updated: 2026-05-16
---

# Local Model Integration Plan — mach-mono

**Goal:** Build a first-class, on-device inference stack for the mach-mono suite — combining Apple FoundationModels (built-in, zero-config) with MLX-Swift (specialized models, embeddings, ASR) under the existing 3-tier `AIProvider` / `AITextGenerationService` / `ProviderBackedAIService` architecture. Privacy by default. Streaming everywhere. No mandatory cloud, no mandatory third-party install.

**Scope:** `Apps/machNotch` (macOS), `Apps/machBrief` (macOS + iOS in v2), `Packages/MachBriefKit`, and a new `Packages/MachIntelligenceKit` package. Both apps consume the same `AITextGenerationService` contract.

**Status:** Planned. Phase 11 (FoundationModels) is the prerequisite; this plan layers MLX on top.

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

- **Not a cloud-AI plan.** No OpenAI/Anthropic/Gemini wiring in the default path. Custom endpoints stay opt-in only, behind Advanced settings.
- **Not a replacement for FoundationModels.** FM remains the default text generator on macOS 26+ for the cases it handles well (summarize, rewrite, extract).
- **Not bundling weights.** Model files are downloaded on first use to a user-visible cache. Avoids App Store size limits and license entanglement.
- **No GPL/MPL dependencies.** Per `docs/decisions/0003-license-policy.md`. MLX-Swift and Hugging Face Hub APIs are MIT/Apache — clean.
- **No telemetry on inference.** Local-only. Zero usage data leaves the device by default.
- **iOS MLX integration is v2.** macOS-first. iOS gets FoundationModels-only in v1 (`docs/prds/machBrief-iOS.md`).

---

## 1. Why Local-First, Why MLX, Why Now

**Privacy.** Notch content, clipboard, calendar, and brief-stream text are intimate. None should leave the device.

**Latency.** A teleprompter that waits 2s on a cloud round-trip is unusable. A local 7B model on Apple Silicon delivers first-token latency under 200ms.

**Cost.** Zero marginal cost per generation enables ambient features (every clipboard event, every notification, every word reveal) that would be prohibitive at cloud rates.

**Apple Silicon is the perfect target.** Unified memory (no GPU↔CPU copy), Metal kernels, and the Neural Engine make on-device inference of 4-bit-quantized 7B–13B models genuinely interactive on M2+ machines.

**Why MLX in addition to FoundationModels.** FoundationModels covers ~70% of mach.notch's AI needs (summarize/rewrite/extract). It does not yet cover: (a) text embeddings for semantic search across shelf/notes/clipboard, (b) automatic speech recognition (Teleprompter Flow Mode, voice notes), (c) larger or specialized chat models for users who want them, (d) on-device classification with custom models, (e) macOS <26 fallback that doesn't require a 4GB Ollama install. MLX fills all five gaps with a single runtime.

---

## 2. Provider Capability Matrix

| Capability | FoundationModels | MLX-Swift | Ollama (opt-in) |
|---|---|---|---|
| **Availability** | macOS 26+ Apple Silicon | macOS 14+ / iOS 17+ Apple Silicon | Anywhere user installs daemon |
| **Setup cost** | None | First-launch model download (~1–4GB) | User installs 4GB+ binary + pulls models |
| **Model size sweet spot** | ~3B distilled by Apple | 1B–13B quantized | 1B–70B |
| **Streaming** | Yes (`session.streamResponse`) | Yes (token stream) | Yes (`stream: true`) |
| **Structured generation** | Yes (`@Generable`) | Via grammar/JSON-mode prompts | Via JSON-mode prompts |
| **Embeddings** | No (today) | Yes (Sentence-Transformers, BGE) | Yes (`nomic-embed-text`) |
| **ASR / Whisper** | No (use `SFSpeechRecognizer`) | Yes (WhisperKit / mlx-examples) | No |
| **Vision / multimodal** | Limited | Yes (LLaVA, Qwen-VL) | Yes |
| **Custom fine-tunes** | No | Yes (LoRA load via `mlx_lm`) | Yes (custom GGUF) |
| **License posture** | First-party | MIT (MLX) + per-model (require Apache/MIT/CC-BY) | MIT, but per-model varies |
| **Default in mach-mono** | ✅ Primary (text) | ✅ Primary (embeddings/ASR), Optional (text) | ❌ Opt-in only |

**Selection rule:**

1. If a `FoundationModels` model handles the task and `macOS ≥ 26`: use it.
2. Else if the task is embeddings, ASR, or a configured specialized model: route to MLX.
3. Else if user explicitly enabled Ollama in Advanced settings: route to Ollama.
4. Else: return `NoAITextGenerationService` deterministic fallback — feature cleanly absent in UI.

---

## 3. Model Survey & Recommended Picks

### 3.1 Chat / Instruction Models (MLX runtime)

| Model | Params | Quant | RAM @ runtime | First-token p50 (M2) | License | Recommended use |
|---|---|---|---|---|---|---|
| **Llama 3.2 1B Instruct** | 1.2B | Q4 | ~1.0 GB | ~80 ms | Llama Community (commercial OK) | 8GB Macs, Notifications digest, Calendar brief |
| **Llama 3.1 8B Instruct** | 8B | Q4 | ~5.0 GB | ~180 ms | Llama Community | Default chat / Teleprompter rewrite on 16GB+ |
| **Qwen 2.5 7B Instruct** | 7B | Q4 | ~4.8 GB | ~170 ms | Apache 2.0 | Cleanest licensing alternative to Llama |
| **Phi-3.5 mini Instruct** | 3.8B | Q4 | ~2.4 GB | ~120 ms | MIT | Best 8GB compromise — solid quality, MIT |
| **Gemma 2 2B Instruct** | 2B | Q4 | ~1.5 GB | ~95 ms | Gemma terms (commercial OK) | Lightweight Clipboard intent classification |

**Default chat pick: Phi-3.5 mini 4-bit.** MIT licensed, fits 8GB Macs, quality competitive with 7B on summarize/rewrite tasks. Upgrade path: Qwen 2.5 7B for 16GB+ users in Advanced settings.

### 3.2 Embedding Models (MLX runtime)

| Model | Dims | Size | License | Recommended use |
|---|---|---|---|---|
| **bge-small-en-v1.5** | 384 | 130 MB | MIT | Default — Shelf semantic search, Notes recall |
| **bge-m3** | 1024 | 2.3 GB | MIT | Multilingual users, opt-in |
| **nomic-embed-text-v1.5** | 768 | 550 MB | Apache 2.0 | Alternative — slightly better English benchmark |

**Default embedding pick: bge-small-en-v1.5.** 130 MB, sub-10ms encoding on M-series, MIT.

### 3.3 ASR Models (MLX runtime via WhisperKit-style port)

| Model | Size | Realtime factor (M2) | Use case |
|---|---|---|---|
| **whisper-tiny.en** | 75 MB | ~0.05× | Real-time teleprompter Flow Mode (Phase 10.2) |
| **whisper-base.en** | 145 MB | ~0.10× | Voice notes transcription |
| **whisper-small.en** | 460 MB | ~0.20× | Quality-first transcription, batch only |
| **Parakeet TDT 0.6B** | 600 MB | ~0.05× | If MLX port stabilizes; lowest WER for English |

**Default ASR pick: whisper-base.en** for quality/size balance, **whisper-tiny.en** for live Flow Mode.

### 3.4 Memory Budget by Apple Silicon Tier

| Mac config | Available for AI | Allowed defaults | Allowed opt-ins |
|---|---|---|---|
| 8 GB unified | ~3 GB | Phi-3.5 mini Q4 + bge-small | none (warn user) |
| 16 GB unified | ~6 GB | Llama 3.1 8B Q4 + bge-small + whisper-tiny | + whisper-base |
| 24 GB unified | ~10 GB | Llama 3.1 8B Q4 + bge-m3 + whisper-base | + Qwen 14B Q4 |
| 32 GB+ unified | ~14 GB+ | any single 13B Q4 model resident | any combination |

`MachIntelligenceKit` reads `ProcessInfo.processInfo.physicalMemory` at startup, computes the budget, and refuses to download/load models that violate it. Users can override in Advanced settings with an explicit "I know what I'm doing" toggle.

### 3.5 Quantization Strategy

- **Default:** 4-bit (`q4_k_m`-style group quantization via MLX). Quality drop is < 2% on most benchmarks, RAM cut ~4×.
- **Premium:** 8-bit on 32GB+ Macs for chat models when user opts into max quality.
- **Embeddings:** keep at fp16 — they're small enough that quantization noise dominates.
- **MXFP4 (Apple's new 4-bit format):** evaluate in M2 milestone when MLX support stabilizes.

---

## 4. Architecture

### 4.1 New Package — `Packages/MachIntelligenceKit`

**License:** MIT (matches `MachBriefKit`, `MacroVisionKit`).

**Why a separate package:** isolates MLX dependency, keeps app target dependency graphs lean, lets `machBrief` consume embeddings without dragging in chat model code, and keeps Bazel build hygiene. Listed under `packages.planned` alongside `MachCore` and `MachUI` in `repo.yaml`.

**Path:** `Packages/MachIntelligenceKit/`

```
Packages/MachIntelligenceKit/
├── Package.swift                                  # SPM shim, Bazel-fed
├── BUILD.bazel                                    # canonical
├── Sources/MachIntelligenceKit/
│   ├── Runtime/
│   │   ├── MLXModelHost.swift                    # actor — loads + holds weights in unified memory
│   │   ├── MLXTokenStream.swift                  # AsyncThrowingStream<Token, Error>
│   │   └── MLXMemoryGuard.swift                  # enforces 3.4 budget
│   ├── Providers/
│   │   ├── MLXTextProvider.swift                 # conforms to AIProvider
│   │   ├── MLXEmbeddingProvider.swift            # conforms to AIEmbeddingService
│   │   └── MLXWhisperProvider.swift              # conforms to AITranscriptionService
│   ├── Registry/
│   │   ├── ModelRegistry.swift                   # @Observable list of installed models
│   │   ├── ModelManifest.swift                   # decodable JSON spec
│   │   ├── ModelDownloader.swift                 # URLSession download with progress
│   │   └── ModelStore.swift                      # on-disk layout, integrity verification
│   ├── Embeddings/
│   │   ├── VectorIndex.swift                     # in-memory HNSW for <10k items
│   │   └── SQLiteVecIndex.swift                  # sqlite-vec backed for ≥10k items
│   └── Protocols/
│       ├── AIEmbeddingService.swift              # NEW
│       └── AITranscriptionService.swift          # NEW
├── Tests/MachIntelligenceKitTests/
│   ├── MLXTextProviderTests.swift
│   ├── ModelRegistryTests.swift
│   └── VectorIndexTests.swift
└── Resources/
    └── default-manifest.json                     # bundled — list of vetted models + checksums
```

### 4.2 External Dependency — MLX-Swift

- **Repo:** `https://github.com/ml-explore/mlx-swift`
- **License:** MIT
- **Pin:** `1.x` (exact version chosen at integration time — pin in `Package.swift` like all other deps).
- **Companion package:** `mlx-swift-examples` for tokenizer + Hugging Face model loaders. Vendor selectively, do not depend on the whole examples repo as a library.
- **Bazel:** add via existing `rules_swift_package_manager`. Verify Metal kernels and `libMLX.dylib` link correctly under `bazel build`. If `rules_swift_package_manager` cannot handle the binary dylib, write a small `swift_library` + `apple_dynamic_framework_import` glue rule. Track in `docs/roadmaps/bazel.md` as Phase 5.

### 4.3 Extended Contracts in the Existing AI Stack

The existing 3-tier stack lives in `Apps/machNotch/machNotch/Plugins/AI/`. To house cross-app contracts, MOVE the protocols (not the providers) into `MachIntelligenceKit` over time. Apps continue to consume `any AITextGenerationService` via `ServiceContainer.ai`.

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

This is backward-compatible — Ollama and FoundationModels providers gain streaming; existing call sites keep working.

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

### 4.4 Model Registry & On-Disk Layout

**Manifest (JSON, signed checksum):**

```json
{
  "schemaVersion": 1,
  "models": [
    {
      "id": "phi-3.5-mini-instruct-q4",
      "kind": "text",
      "family": "phi",
      "params": "3.8B",
      "quant": "Q4_K_M",
      "sizeBytes": 2415919104,
      "minRAMBytes": 3221225472,
      "license": "MIT",
      "sha256": "…",
      "huggingfaceID": "mlx-community/Phi-3.5-mini-instruct-4bit",
      "files": ["weights.safetensors", "tokenizer.json", "config.json"]
    },
    {
      "id": "bge-small-en-v1.5",
      "kind": "embedding",
      "dimension": 384,
      "sizeBytes": 134217728,
      "minRAMBytes": 268435456,
      "license": "MIT",
      "sha256": "…",
      "huggingfaceID": "mlx-community/bge-small-en-v1.5-mlx"
    },
    {
      "id": "whisper-base-en",
      "kind": "asr",
      "sizeBytes": 152043520,
      "minRAMBytes": 536870912,
      "license": "MIT",
      "sha256": "…",
      "huggingfaceID": "mlx-community/whisper-base.en-mlx"
    }
  ]
}
```

**On-disk layout:**

```
~/Library/Application Support/com.larsboes.machnotch/Models/
├── manifest.json                          # cached + verified at launch
├── phi-3.5-mini-instruct-q4/
│   ├── weights.safetensors
│   ├── tokenizer.json
│   └── config.json
├── bge-small-en-v1.5/
│   └── …
└── whisper-base-en/
    └── …
```

Shared via App Group `group.com.larsboes.mach-mono` so `machBrief` reads the same model directory (no double-download). `MachBriefKit` adds a thin read-only wrapper for embeddings.

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

`AIManager` is renamed/upgraded to support all three modalities; the existing `AIManager.init()` overload that auto-registers `OllamaProvider` is removed (Phase 11.6 prerequisite — see §6.1).

### 4.6 Concurrency Discipline

- `MLXModelHost` is an `actor`, NOT `@MainActor`. Inference runs off the main thread; results delivered via `await` to the main-actor service wrapper.
- `MLXTextProvider`, `MLXEmbeddingProvider`, `MLXWhisperProvider` are `Sendable` structs holding a reference to the host actor.
- `ProviderBackedAIService` stays `@MainActor` but `await`s all provider calls — no UI block.
- Streaming uses `AsyncThrowingStream` so SwiftUI can render token-by-token without blocking.

---

## 5. Integration Points

### 5.1 machNotch — TeleprompterPlugin

Replaces the current Ollama-only `aiAssist` (`Apps/machNotch/machNotch/Plugins/BuiltIn/TeleprompterPlugin/TeleprompterState.swift:146`) with the streaming `AITextGenerationService`:

- AI-assisted rewrite renders tokens incrementally in `TeleprompterExpandedView`.
- Flow Mode (`docs/prds/machNotch.md` §10.2) uses `AITranscriptionService.transcribeStream` to drive `VoiceScrollEngine` directly — replaces today's `SFSpeechRecognizer` dependency where MLX is faster/lower-latency.
- `TeleprompterAIAction` enum gains the Phase 11.4 actions (expandBullets, simplify, addPauses, translateStyle, timeToTarget) — implemented as prompts in `ProviderBackedAIService`.

### 5.2 machNotch — ClipboardPlugin

- Live intent classification using **Gemma 2 2B Q4** or **Phi-3.5 mini Q4**: prompt classifies into `{url, email, code, command, plaintext, ...}` → drives suggested action chips in the closed/expanded view.
- Action extraction on long-text clipboards: "extract action items" → bullet list rendered in expanded panel.
- All inference on a background actor; UI never blocks even on slow first-token.

### 5.3 machNotch — NotificationsPlugin

- Notification burst digest: when ≥3 notifications arrive within 60s, run a single MLX summarize call with strict 64-token cap → display a "3 messages: …" rolled-up card.
- Embedding-based deduplication: hash near-identical notifications via embeddings (cosine similarity > 0.92) so Slack DMs aren't shown three times.

### 5.4 machNotch — CalendarPlugin

- "Next meeting" 1-sentence brief: combine attendees + description + agenda doc (if linked) → 1-line spoken brief 5 minutes before the meeting.
- Implemented as a `MeetingBriefService` that calls `ai.draftIntro(topic:, durationSeconds:)`-style API.

### 5.5 machNotch — DisplaySurfacePlugin

- The Local API `POST /api/v1/display/text` endpoint (`docs/prds/machNotch.md` §6/§6b) gains an opt-in `compress: true` parameter — text longer than the notch can display is compressed via `ai.summarize(maxTokens: 32)` before render.
- For long terminal output piped into the notch ("build progress"), summarize streaming so the user sees rolling status without waiting for completion.

### 5.6 machNotch — ShelfPlugin

- Semantic search across all shelf items by name + extracted file text (PDFs, txt, code). Indexed via `bge-small-en-v1.5` → `SQLiteVecIndex` for ≥10k items, in-memory HNSW under.
- New keyboard shortcut "find anything" opens a search field in the expanded panel; types a query → top 5 matches in <50ms.

### 5.7 machBrief — MoodCheckInSource (v2)

- Mood AI (already on machBrief v2 ideas list): use embeddings to cluster mood notes over time, then summarize patterns weekly. Output as a brief entry on Sunday evening: "this week you felt good on focus days, low on meeting-heavy days."

### 5.8 machBrief — WordSource enrichment

- When the bundled definition is missing or thin, optional `Phi-3.5 mini` rewrite produces a memorable example sentence — entirely offline, no Dictionary API dependency. User-toggleable; off by default.

### 5.9 Local HTTP API

Expose at `127.0.0.1:19384` (existing `LocalAPIServer`):

| Endpoint | Body | Purpose |
|---|---|---|
| `POST /api/v1/ai/generate` | `{prompt, config?}` | Non-streaming generate |
| `POST /api/v1/ai/stream` | `{prompt, config?}` | SSE stream of tokens |
| `POST /api/v1/ai/embed` | `{texts: […]}` | Returns vectors |
| `POST /api/v1/ai/transcribe` | multipart audio | Returns transcript |
| `GET /api/v1/ai/models` | — | Lists installed + available models |
| `POST /api/v1/ai/models/{id}/download` | — | Triggers download with progress events on WS |

Auth: localhost-only by default (per `docs/prds/machNotch.md` §8 LocalAPIConfig). Same posture as existing routes.

---

## 6. Infrastructure & Code Debt

### 6.1 Phase 11.6 is a hard prerequisite

`Apps/machNotch/machNotch/Plugins/AI/AIManager.swift:31` currently does:

```swift
registerProvider(OllamaProvider())
activeProviderId = "ollama"
```

Auto-registering Ollama makes provider selection ambiguous the moment a second provider exists. **Phase 11.6 (`docs/prds/machNotch.md`) — remove Ollama from default init — must land before MLXProvider is added.** Otherwise the AIManager will pick Ollama over MLX on a freshly installed machine that has Ollama running for unrelated reasons.

### 6.2 `AIProvider` lacks streaming

`Apps/machNotch/machNotch/Plugins/AI/AIProvider.swift` exposes only `generate(prompt:config:) async throws -> String`. Add `generateStream` with backward-compatible default impl (§4.3). All current consumers (`ProviderBackedAIService.rewrite/summarize/section/draftIntro`) gain corresponding `*Stream` variants returning `AsyncThrowingStream<String, Error>`.

### 6.3 `AITextGenerationService` is `@MainActor`

`Apps/machNotch/machNotch/Plugins/AI/AITextGenerationService.swift:7` is annotated `@MainActor`. For Ollama and FoundationModels this is fine because the heavy lifting happens server-side or via a built-in framework actor. For MLX, multi-second generations on the main actor will jank the UI. Resolution:

1. Keep the public `AITextGenerationService` `@MainActor` (it's the API surface plugins use).
2. The MLX-backed implementation funnels work to a private `actor MLXModelHost` and `await`s — main actor yields between awaits.
3. Streaming via `AsyncThrowingStream` makes this seamless.

No protocol change. Just disciplined implementation.

### 6.4 `isAvailable` sync/async mismatch

`AIProvider.isAvailable` is `var isAvailable: Bool { get async }` — async, requires await. `ProviderBackedAIService.isAvailable` is sync (`var isAvailable: Bool { true }`). Plugins reading `service.isAvailable` get a misleading constant `true`. Fix: make `AITextGenerationService.isAvailable` async too, OR cache the last-known async value in the service with a `refresh()` method. Recommend: async — single source of truth, callers `await` it once at plugin activation.

### 6.5 No embeddings infrastructure

No vector index exists today. Plan adds:

- `AIEmbeddingService` protocol (§4.3)
- `VectorIndex` in-memory HNSW for small corpora
- `SQLiteVecIndex` using `SQLite.swift` (already a workspace dep, `Package.swift`) + the `sqlite-vec` extension for larger corpora
- Migration policy: when an indexed collection crosses 10k items, auto-migrate from memory to sqlite-vec

### 6.6 No model lifecycle

There is currently no UI or service for downloading, updating, or deleting a model. Plan adds:

- `ModelDownloader` (URLSession, resumable, progress published via `PluginEventBus`)
- `ModelStore` for on-disk integrity (sha256 verify on load)
- `ModelRegistry` `@Observable` — feeds a new "AI Models" pane in Settings
- App-group sharing so `machBrief` re-uses what `machNotch` downloaded

### 6.7 Bazel + MLX

`docs/roadmaps/bazel.md` is currently at Phase 3/4. Adding MLX requires:

- Confirm `rules_swift_package_manager` correctly generates `swift_library` targets for `mlx-swift` + its Metal `.metallib` resources.
- If not: add `apple_dynamic_framework_import` rule for `libMLX.dylib` and a `swift_library` glue target.
- Add `bazel test //Packages/MachIntelligenceKit:MachIntelligenceKitTests` to CI matrix.
- Verify code signing of any embedded dylibs in `Apps/machNotch/BUILD.bazel` (existing `codesign --deep` step in `build_reusable.yml` should cover it — verify).

### 6.8 Privacy & permissions

Establish written policy in this plan, then enforce in code:

- AI features are per-plugin opt-in. Default state: off. First-launch onboarding shows what each feature does.
- Zero telemetry from `MachIntelligenceKit`. No anonymous usage stats. No remote error reporting.
- Model downloads use only Hugging Face's CDN (or a configurable mirror) over HTTPS with sha256 verification.
- No cloud fallback is silently inserted. If MLX fails, behavior is `NoAITextGenerationService` (clean absence), never a cloud call.
- Settings UI shows running models, RAM usage, and a one-click "unload all models" button.

### 6.9 `Package.swift` is a Bazel-feeding shim

`Package.swift` at repo root says `products: []` — it exists only so `rules_swift_package_manager` can resolve deps. Adding `mlx-swift` means:

1. Add `.package(url: "https://github.com/ml-explore/mlx-swift", exact: "<pin>")` to `dependencies` list.
2. Regenerate Bazel deps lockfile.
3. In `Packages/MachIntelligenceKit/BUILD.bazel`, list `@swiftpkg_mlx_swift//:MLX` (or generated name) as a `deps`.

---

## 7. Phased Delivery

Each milestone has explicit acceptance criteria. No milestone closes until all criteria pass `bazel build` + `bazel test` + manual smoke.

### M0 — Foundation & Contracts (1–2 weeks)

**Goal:** Land the contracts and clean up the AI stack so MLX can plug in without breaking anything.

**Work:**
- Phase 11.6 refactor: remove `OllamaProvider` auto-registration from `AIManager.init()`.
- Add `generateStream` to `AIProvider` with default impl (§4.3).
- Add `AIEmbeddingService` + `AITranscriptionService` protocols.
- Make `AITextGenerationService.isAvailable` async (§6.4).
- Create empty `Packages/MachIntelligenceKit` skeleton (no MLX yet) + `BUILD.bazel`.
- Add `MachIntelligenceKit` to `repo.yaml` under `packages.planned → existing`.

**Acceptance:**
- `bazel build //Apps/machNotch:machNotch` green.
- `bazel test //Apps/machNotch:machNotchTests //Packages/MachBriefKit:MachBriefKitTests` green.
- `AIManager()` creates with zero providers registered; AI features cleanly absent.
- Existing teleprompter AI assist still works when user manually opts into Ollama via Advanced settings.

### M1 — MLX Runtime + MLXTextProvider (2 weeks)

**Goal:** First MLX text generation working end-to-end behind the existing service contract.

**Work:**
- Integrate `mlx-swift` SPM dep, resolve Bazel glue (§6.7).
- Implement `MLXModelHost` actor + `MLXTextProvider`.
- Implement `ModelRegistry`, `ModelDownloader`, `ModelStore` with `phi-3.5-mini-instruct-q4` as the only registered model.
- Settings UI: "AI Models" pane with download button + progress.
- Wire `MLXTextProvider` into `AIManager` selection rule (§2).

**Acceptance:**
- Fresh install on M2/16GB: open Settings → AI Models → Download Phi-3.5 mini → generation works in Teleprompter rewrite.
- Memory guard refuses download on 8GB Mac unless user toggles override.
- `bazel test //Packages/MachIntelligenceKit:MachIntelligenceKitTests` includes a tokenizer round-trip test.
- Cold first-token latency on M2 ≤ 250ms.

### M2 — Streaming + Teleprompter Live UX (1 week)

**Goal:** Token-by-token rendering in user-visible flows.

**Work:**
- Implement streaming for `MLXTextProvider.generateStream`.
- Add streaming variants to `AITextGenerationService` (rewriteStream, summarizeStream, draftIntroStream).
- Update `TeleprompterControlPanel` AI action handlers to consume the stream and render tokens live.
- Add `DisplaySurface` `compress: true` path.

**Acceptance:**
- Teleprompter "rewrite" shows tokens appearing within 300ms of click.
- `POST /api/v1/ai/stream` returns SSE that a `curl -N` consumer can read incrementally.
- No main-thread block over 16ms during generation (verify via Instruments).

### M3 — Embeddings + Shelf Semantic Search (1–2 weeks)

**Goal:** Embeddings infrastructure operational; first user-visible feature uses it.

**Work:**
- Implement `MLXEmbeddingProvider` with `bge-small-en-v1.5`.
- Implement `VectorIndex` (in-memory HNSW) and `SQLiteVecIndex`.
- Shelf indexer: extract text from added items (TXT/MD/PDF via PDFKit), embed, store.
- Shelf semantic search UI (Cmd-K palette in expanded panel).

**Acceptance:**
- 10k synthetic items: search query → top-5 results in <50ms.
- Index rebuilds incrementally when items added; no full re-index.
- Index persists across restart; verified by sha256 of vector blobs.

### M4 — Transcription + Teleprompter Flow Mode (2 weeks)

**Goal:** ASR-driven scroll speed working.

**Work:**
- Implement `MLXWhisperProvider` (whisper-base.en + tiny.en).
- Replace `SFSpeechRecognizer` path in `VoiceScrollEngine` with `AITranscriptionService.transcribeStream` — keep `SFSpeechRecognizer` as fallback if Whisper not downloaded.
- Notifications digest using same provider.

**Acceptance:**
- 60s of speech transcribed in <2s on M2.
- Flow Mode scroll lock-on to recognized words within 200ms.
- WER on test set ≤ 8% (whisper-base.en target).

### M5 — Cross-App, machBrief, Hardening (open-ended)

**Goal:** machBrief consumes the same model store; rough edges removed.

**Work:**
- App-Group model directory sharing.
- `machBrief` Mood AI clustering using embeddings.
- Optional `WordSource` enrichment.
- Model auto-update flow (manifest version bumps).
- Battery-aware throttling (don't run inference at <20% on battery unless user opts in).

**Acceptance:**
- `machBrief` reads models from app group without re-downloading.
- Weekly mood brief generates correctly on a test dataset.
- Battery-aware throttle measurably reduces inference rate at low battery.

---

## 8. Risk Register

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | `mlx-swift` will not build under Bazel `rules_swift_package_manager` | Medium | Blocks M1 | Spike in M0 first; fall back to hand-written `apple_dynamic_framework_import` glue |
| 2 | Apple Silicon 8GB Macs cannot comfortably run any chat model | Medium | Limits user base | Default to Phi-3.5 mini Q4 (3GB), hard refuse larger; clean-absence UI on 8GB |
| 3 | Model weights' licenses change (Llama community license terms shift) | Low | Re-distribution legal risk | Default to MIT/Apache-licensed models (Phi/Qwen/bge); Llama is opt-in |
| 4 | MLX-Swift API churn breaks integration between major versions | Medium | Maintenance cost | Pin exact version like every other dep; allocate a quarterly bump window |
| 5 | Concurrent FoundationModels + MLX providers compete in `AIManager` | High if §6.1 skipped | Wrong provider used | §6.1 prerequisite: remove auto-registration; deterministic selection rule §2 |
| 6 | `@MainActor` UI freezes during MLX inference | High if implemented naively | UX disaster | Actor-isolate `MLXModelHost`; streaming default; Instruments verification in M2 |
| 7 | Model download fails / corrupts mid-stream | Medium | Broken AI features | Resumable downloads + sha256 verify + auto-redownload on hash mismatch |
| 8 | Sparkle auto-update ships a new app version with mismatched model manifest | Low | Confusing errors | Manifest carries `schemaVersion`; app refuses to load incompatible manifests, prompts user to update models |
| 9 | Cloud-feature creep — someone adds an OpenAI provider "for testing" | Low | Privacy regression | Document non-goal §0 in `PLAN.md`; CODEOWNERS review for `Providers/` |
| 10 | Embedding index disk size explodes on power users | Medium | Disk pressure | Quantize embeddings to int8 in `SQLiteVecIndex`; expose "rebuild index" button |
| 11 | MLX cannot run reliably on macOS <14 | Known | Constrains support matrix | App already targets macOS 26 (`repo.yaml`) — non-issue |
| 12 | Battery drain from background inference | Medium | User complaints | Battery-aware throttle in M5; never run inference proactively at <20% battery |

---

## 9. Dependency Sequencing

```
M0 (contracts) ─┬─► M1 (MLX text) ─► M2 (streaming UX)
                │
                ├─► M3 (embeddings) ──► M5 (cross-app + machBrief mood)
                │       └──► Shelf semantic search
                │
                └─► M4 (ASR) ─► Teleprompter Flow Mode
                            └─► Notifications digest (if reusing summarize)
```

**Hard ordering:**
1. M0 first — none of the rest is safe without §6.1.
2. M1 before M2/M3/M4 — they all need the runtime + model registry.
3. M2 before M3 — embeddings UX benefits from streaming-aware patterns.
4. M5 last — synthesizes everything else.

**Parallel-safe:** M3 and M4 can be done concurrently by different contributors after M1.

---

## 10. Open Questions

1. **Hugging Face dependency vs. self-hosted mirror.** Default download source = HF CDN. Should we mirror on GitHub Releases for reliability? (Recommend: yes, for the 3 default models. Larger opt-ins continue to use HF.)
2. **Tokenizer vendoring.** `mlx-swift-examples` provides a Swift tokenizer port. Should `MachIntelligenceKit` vendor it directly, or depend on the examples repo? (Recommend: vendor — examples repo is not API-stable.)
3. **Vector DB choice.** `sqlite-vec` is young (post-1.0 but recent). Alternative: pure-Swift FAISS port. (Recommend: stick with sqlite-vec; revisit if it stalls.)
4. **macOS <26 fallback for text generation.** If a 8GB / Intel Mac user enables AI, what runs? FoundationModels unavailable, MLX unavailable. (Recommend: clean absence — feature simply does not appear. No Ollama nag screen.)
5. **WhisperKit vs. mlx-examples whisper.** Both exist. WhisperKit is more polished; mlx-examples is closer to our runtime. (Recommend: mlx-examples port — single runtime, fewer deps.)
6. **Cross-process model sharing.** Multiple app instances loading the same 5GB model = 10GB RAM. Single-instance enforcement at app level handles this for `machNotch` (it's single-instance), but if `machBrief` also loads chat models, design carefully. (Recommend: machBrief uses embeddings only; chat stays in machNotch.)

---

## 11. Appendix — File-by-File Footprint

| File | Change | Why |
|---|---|---|
| `Apps/machNotch/machNotch/Plugins/AI/AIManager.swift` | Remove auto-register of Ollama (§6.1) | Provider ambiguity |
| `Apps/machNotch/machNotch/Plugins/AI/AIProvider.swift` | Add `generateStream` + default impl | Streaming |
| `Apps/machNotch/machNotch/Plugins/AI/AITextGenerationService.swift` | Make `isAvailable` async; add `*Stream` methods | API consistency |
| `Apps/machNotch/machNotch/Plugins/AI/ProviderBackedAIService.swift` | Implement `*Stream` variants | Streaming UX |
| `Apps/machNotch/machNotch/Plugins/Services/System/ServiceContainer.swift` | Add `embeddings` and `transcription` fields | DI for new services |
| `Apps/machNotch/machNotch/Plugins/Core/ServiceProviderProtocols.swift` | Mirror new fields in protocol | DI plumbing |
| `Apps/machNotch/machNotch/AppObjectGraph.swift` | Wire `AISubsystemFactory` | DI root |
| `Packages/MachIntelligenceKit/**` | New package, all files | New runtime |
| `Package.swift` | Add `mlx-swift` dep | Bazel-feeding |
| `repo.yaml` | Promote `MachIntelligenceKit` from planned → existing | Manifest truth |
| `docs/roadmaps/bazel.md` | Phase 5 entry: MLX/Metal verification | Bazel posture |
| `docs/prds/machNotch.md` | Phase 17 (or extend Phase 11) referencing this PLAN | Cross-link |
| `docs/architecture/overview.md` | New layer note: AI subsystem | Architecture truth |

---

## 12. References

- Existing AI stack: `Apps/machNotch/machNotch/Plugins/AI/{AIManager,AIProvider,OllamaProvider,ProviderBackedAIService,NoAITextGenerationService,AITextGenerationService}.swift`
- Phase 11 plan: `docs/prds/machNotch.md` §Phase 11 (lines 908–1147)
- Plugin architecture: `docs/architecture/plugin-system.md`
- Architecture overview: `docs/architecture/overview.md`
- machBrief PRDs: `docs/prds/machBrief-macOS.md`, `docs/prds/machBrief-iOS.md`
- Bazel roadmap: `docs/roadmaps/bazel.md`
- Repo manifest: `repo.yaml`
- MLX-Swift: https://github.com/ml-explore/mlx-swift
- MLX examples (tokenizer + loaders): https://github.com/ml-explore/mlx-swift-examples
