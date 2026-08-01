---
id: machNotch
product: machNotch
display_name: mach.notch
status: active
phase: "10-teleprompter / 12-audio-visualizer / 16-new-plugins"
owner: larsboes
source_of_truth: true
related:
  app: Apps/machNotch
  agent_instructions: Apps/machNotch/CLAUDE.md
  architecture: docs/Architecture.md
  plugin_guide: docs/Guide.md
license:
  current: GPL-3.0
  target: MIT
---

> **Convention — `phase` in front matter:** Whenever you change which rows are **Active** (or materially shift active implementation tracks) in the **Current State** section’s phase table, update the YAML `phase` field above to match. That keeps machine-readable front matter aligned with the narrative plan so agents and search tools do not diverge.

# mach.notch — PRD + Implementation Plan

**Goal:** Transform mach.notch from a polished notch replacement into a **local-first ambient display platform** — beautiful UX, API-driven extensibility, and a plugin ecosystem. Part of the [mach-mono](https://github.com/larsboes/mach-mono) suite.

**Architecture:** Plugin-first + DI via ServiceContainer + @Observable/@MainActor throughout. Every feature is a plugin. Views never construct services. All cross-plugin communication via PluginEventBus.

**Architecture update (2026-06-13):** Bazel now mirrors the plugin model:
`NotchPluginCore` plus one `swift_library` per built-in plugin. The app entry
target is a tiny launcher over `machNotch_Lib`, built-in UI reach-through from
app views is routed through the `NotchPlugins` facade, and the default app build
does not depend on `MachSoundKit` / AudioKit. Soundscape is available only through
the explicit `NotchPluginsWithSoundscape` opt-in target. Lazy plugin descriptors and
strict on-demand loading are fully implemented at runtime (consolidated in [Architecture.md](file:///Users/larsboes/Developer/mach-mono/docs/Architecture.md)).

**Tech Stack:** Swift 6+, SwiftUI/AppKit, Defaults (settings), Combine (publishers), XPC helper, Sparkle (updates), Lottie (animations), KeyboardShortcuts

**Build:** `bazel build //Apps/machNotch:machNotch`
**Plugin tests:** `bazel test //Packages/NotchPlugins:NotchPluginsTests`

### Key Constraints

- **300-line hard limit per file**
- DDD & SOLID Architecture
- **No new singletons** — `AppObjectGraph` is the only DI root
- **Protocol before implementation** — new services get a protocol first
- **Build must stay green** — no broken intermediate commits
- **One commit per logical unit** — enables rollback
- **Tests before ship** — every new plugin gets unit tests
- **Git Flow** — Follow [/git-flow](file:///.agent/workflows/git-flow.md) and [GIT_FLOW.md](file:///.agent/rules/GIT_FLOW.md)
- **API-first for new plugins** — if a plugin can be API-driven, it should be

### Files to Not Touch

- `Plugins/Core/NotchPlugin.swift` — stable protocol
- `Plugins/Core/PluginEventBus.swift` — stable; add new event types as new structs
- `Core/NotchStateMachine.swift` — pure and tested; only modify for state logic changes
- `private/MachWindowSpace.swift` — private API wrapper
- `mediaremote-adapter/` — pre-built framework, read-only
- `XPCHelperClient/XPCHelperClient.swift` — stable XPC client, service name is `com.larsboes.machnotch.xpc-helper`

---

## License Migration — GPL v3 → MIT

**Current state:** Both `/LICENSE` (root) and `Apps/machNotch/LICENSE` are GPL v3, inherited from the BoringNotch fork. The former MPL `CGSSpace.swift` path has been replaced by `MachWindowSpace.swift`; no remaining Parrot/MPL attribution is shipped in machNotch third-party notices. `MacroVisionKit` is already MIT. `MachBriefKit` and `Apps/machBrief/` will be MIT from creation.

**Goal:** Relicense machNotch and the mach-mono root to MIT once all BoringNotch-origin code is genuinely reengineered. This is a deliberate, file-by-file process — not a one-liner. Renaming `Boring*` → `Notch*` was cosmetic; rewriting the logic is the actual work.

**Principle:** Reengineering means understanding what a component does, then implementing the same behavior from scratch with different design choices. The ideas, APIs, and patterns are not owned by BoringNotch. The specific expression in code is. Replace the expression.

**Evidence ledger:** [`docs/Licensing.md`](../../docs/Licensing.md) is the working status ledger for reengineering evidence, retained compatible third-party code, and remaining closeout blockers.

---

### CGSSpace.swift — Reengineering Plan

**File:** `private/CGSSpace.swift` | **Current license:** MPL 2.0 (avaidyam/Parrot) | **Size:** 64 lines

**Can it be rewritten?** Yes. The file has two parts:

1. **`@_silgen_name` declarations** — Swift bindings to private macOS C functions (`CGSSpaceCreate`, `CGSSpaceDestroy`, etc.). These are factual interface declarations to system APIs, not creative authorship. The same declarations appear in dozens of open-source macOS projects (yabai, AeroSpace, Amethyst, etc.). Not copyrightable.

2. **`CGSSpace` class wrapper** — ~30 lines. Simple `NSWindow` set that syncs to a CGS space on change. Trivially rewritable.

**Rewrite approach:** Create `private/MachWindowSpace.swift` (MIT) from scratch:

- Rename class to `MachWindowSpace`
- Keep same `@_silgen_name` declarations (factual, not creative)
- Redesign wrapper: use `windowNumbers: [CGWindowID]` directly instead of `Set<NSWindow>` — cleaner, no AppKit dependency in the type
- Add `@MainActor` conformance consistent with the codebase
- Remove MPL header entirely — fresh file, fresh license
- Delete `CGSSpace.swift` after all call sites are updated
- Update `CLAUDE.md` "Files to Not Touch" to reference `MachWindowSpace.swift`

**Effort:** ~1 hour. Low risk — pure rename + minor interface redesign.

---

### Reengineering Checklist — BoringNotch Origin

Files/areas that were **renamed** (cosmetic) rather than **rewritten** (genuine). Each needs a rewrite pass before the MIT relicense is clean.

| Area | Status | Notes |
|------|--------|-------|
| `CGSSpace.swift` | ✅ Rewritten | See `MachWindowSpace.swift` (MIT) |
| `NotchViewModel` | ✅ Rewritten | Re-authored `ViewModel/NotchViewModel*.swift` (behavior parity); verified build + tests 2026-05-04 |
| `NotchViewCoordinator` | ⏳ Audit needed | Was `BoringViewCoordinator` — check for original logic |
| `NotchStateMachine` | ✅ Likely clean | Pure state machine, extensively tested, logic is independent |
| `ContentView` | ⏳ Audit needed | Likely carries original layout structure |
| `Core/Controllers/` | ⏳ Audit needed | HoverController, SizeCalculator — check origin |
| `MusicPlugin` | ⏳ Audit needed | Most plugin logic is likely original (mediaremote-adapter is read-only framework) |
| `BatteryPlugin` | ✅ Likely clean | Standard IOKit pattern, no unique BoringNotch logic |
| `HabitTrackerPlugin` | ✅ Clean | Built entirely after fork — original work |
| `TeleprompterPlugin` | ✅ Clean | Built entirely after fork — original work |
| Plugin architecture (`NotchPlugin`, `PluginEventBus`, `PluginContext`) | ✅ Likely clean | Architecture redesign is substantial original work |
| `AppObjectGraph` (DI root) | ✅ Likely clean | DI pattern introduced post-fork |
| `private/LocalAPI/` | ✅ Clean | Built entirely after fork — original work |
| `sizing/matters.swift` | ✅ Rewritten | Reauthored as `NotchGeometry` with compatibility wrappers; covered by `LicenseMigrationReengineeringTests` |
| `observers/FullscreenMediaDetection.swift` | ✅ Rewritten | Reauthored around snapshot policy; covered by `LicenseMigrationReengineeringTests` |
| `observers/MediaKeyInterceptor.swift` | ✅ Rewritten | Split into event parsing, routing, feedback playback, and event-tap ownership |
| `components/Notch/NotchHomeView.swift` | ✅ Rewritten | Reauthored layout expression and removed direct Defaults dependency |
| `components/Notch/NotchExtrasMenu.swift` | ✅ Rewritten | Reauthored current menu tile behavior |

**Process for each "Audit needed" file:**

1. Read the file — identify logic that looks like it came verbatim from BoringNotch vs. post-fork additions
2. If uncertain: rewrite the file from scratch using the current behavior as the spec
3. Mark ✅ in this table
4. When all rows are ✅: update both `LICENSE` files to MIT, update CLAUDE.md

**Do not rush this.** Each rewrite is a build-and-test cycle. One file per PR.

### Reengineering Execution Roadmap (Detailed)

This roadmap converts the checklist above into a deterministic sequence with explicit verification and relicensing gates. It is intentionally separate from feature phases (10/11/12/16) and tracks only legal/architectural reengineering work.

#### Canonical Verification Commands (run after each rewrite pass)

- Build: `bazel build //Apps/machNotch:machNotch`
- Test: `bazel test //Apps/machNotch:machNotchTests`

#### Execution Order (priority + rationale)

| Order | Target | Why this order |
|------:|--------|----------------|
| 1 | `NotchViewModel` (`ViewModel/NotchViewModel.swift` + extensions) | Highest behavioral centrality; downstream coordinator/content rewrites depend on this contract. |
| 2 | `ContentView` (`ContentView.swift`) | Locks visual/state rendering parity once view-model behavior is stabilized. |
| 3 | `NotchViewCoordinator` (`NotchViewCoordinator.swift`) | Coordination layer can be rewritten with stable VM/UI seams. |
| 4 | `Core/Controllers/` (`NotchHoverController.swift`, `NotchSizeCalculator.swift`, `NotchCameraController.swift`) | Controller policies become clearer after VM/coordinator boundaries are reset. |
| 5 | `MusicPlugin` (`Plugins/BuiltIn/MusicPlugin/MusicPlugin.swift`) | Plugin rewrite last to avoid coupling churn while core notch layers are being reworked. |

#### Target 1 — NotchViewModel Rewrite Plan

**Scope**

- `ViewModel/NotchViewModel.swift`
- `ViewModel/NotchViewModel+Hover.swift`
- `ViewModel/NotchViewModel+Observers.swift`
- `ViewModel/NotchViewModel+Camera.swift`

**Rewrite strategy**

- Re-spec behavior from current runtime outcomes (open/close transitions, sneak peek state, hover semantics, plugin display transitions).
- Preserve DDD boundaries: orchestration only; no direct service construction; no singleton fallback paths.
- Keep state-machine delegation explicit (`NotchStateMachine` as single phase authority).

**Definition of done**

- File family is re-authored from behavior spec (not textual transformation).
- Existing behavior remains parity-correct for open/close, hover, and active plugin routing.
- Reengineering checklist row for `NotchViewModel` can move to `✅ Rewritten`.

**Rollback note**

- If regressions appear, revert this rewrite unit only and keep checklist status at `⏳`.

#### Target 2 — ContentView Rewrite Plan

**Scope**

- `ContentView.swift`

**Rewrite strategy**

- Reconstruct view composition from current UX contract: shell, overlays, phase-driven rendering, plugin panel slotting.
- Keep animation hooks and environment hand-offs (`contentProgress`, phase gates) behavior-equivalent.
- Maintain "views render, services resolve in DI root" rule.

**Definition of done**

- UI parity preserved for closed/open transitions and plugin content placement.
- No architectural regression (no service construction in view layer).
- Reengineering checklist row for `ContentView` can move to `✅ Rewritten`.

**Rollback note**

- If parity diverges, revert this unit and keep existing production rendering path.

#### Target 3 — NotchViewCoordinator Rewrite Plan

**Scope**

- `NotchViewCoordinator.swift`

**Rewrite strategy**

- Rebuild coordinator responsibilities from first principles: window lifecycle, placement updates, notch state propagation, and app lifecycle integration.
- Preserve strict separation from domain state machine logic.
- Keep dependency flow through injected services/protocols only.

**Definition of done**

- Coordinator behavior matches current production window/control behavior.
- Layer boundary remains clean (coordination infra only).
- Reengineering checklist row for `NotchViewCoordinator` can move to `✅ Rewritten`.

**Rollback note**

- Coordinator regressions are high impact; rollback immediately if window lifecycle becomes unstable.

#### Target 4 — Core Controllers Rewrite Plan

**Scope**

- `Core/NotchHoverController.swift`
- `Core/NotchSizeCalculator.swift`
- `Core/NotchCameraController.swift`

**Rewrite strategy**

- Rewrite each controller as policy-focused, independently testable logic modules.
- Preserve existing contracts consumed by VM/coordinator.
- Keep calculations deterministic and side effects explicit.

**Definition of done**

- Hover timing, size policy, and camera tracking behavior remain parity-consistent.
- Controllers remain free of UI-layer rendering responsibilities.
- Reengineering checklist row for `Core/Controllers/` can move to `✅ Rewritten`.

**Rollback note**

- Revert only the affected controller if one policy path regresses; avoid broad rollback across all three.

#### Target 5 — MusicPlugin Rewrite Plan

**Scope**

- `Plugins/BuiltIn/MusicPlugin/MusicPlugin.swift`
- `machNotchTests/MusicPluginTests.swift` (update/add tests if behavior-facing changes are needed)

**Rewrite strategy**

- Reimplement plugin behavior from plugin contract (`NotchPlugin`) + current user-facing behavior.
- Keep service access through `PluginContext` abstractions (media/system services), no concrete reach-through.
- Preserve route/event and display-priority behavior expected by PluginManager.

**Definition of done**

- Existing `MusicPluginTests` pass; extend coverage if new internal seams are introduced.
- Plugin behavior parity maintained (controls, metadata display, state synchronization).
- Reengineering checklist row for `MusicPlugin` can move to `✅ Rewritten`.

**Rollback note**

- If media controls regress, rollback plugin unit and keep prior implementation until tests are strengthened.

#### MIT Relicensing Closeout Gate

Do not flip licenses until all conditions below are true:

1. Every `⏳ Audit needed` row in the reengineering table is `✅ Rewritten`.
2. Build and full test suite are green after final rewrite pass.
3. Documentation synchronization is complete:
    - `Plans/PRDs/machNotch.md` checklist/status rows updated
   - `repo.yaml`, `AGENTS.md`, and root `README.md` reflect final relicensing state
4. Only then update both license files in one atomic change:
   - root `LICENSE`
   - `Apps/machNotch/LICENSE`

#### Risk Register (Reengineering Track)

| Risk | Impact | Mitigation |
|------|--------|------------|
| `NotchViewModel` rewrite alters phase transitions | High | Keep `NotchStateMachine` contract as source of truth; run full tests after each VM pass. |
| `ContentView` rewrite drifts from shipped UX | Medium | Use behavior-first acceptance checks and visual sanity verification before checklist flip. |
| Controller rewrite changes hover/size timing subtly | Medium | Rewrite one controller at a time and verify deterministic behavior paths. |
| `MusicPlugin` rewrite breaks media control semantics | Medium | Preserve plugin contract boundaries and maintain/extend `MusicPluginTests`. |

---

## Current State (2026-05-04)

**Repo:** `larsboes/mach-mono` — monorepo, `main` branch only. App lives at `Apps/machNotch/`.
**Build:** ✅ `BUILD SUCCEEDED` (verified 2026-05-04 via `bazel build //Apps/machNotch:machNotch`)
**Tests:** ✅ 53/53 passing across 7 suites — APIRouterTests (4), BatteryPluginTests (10), ExportablePluginTests (7), MusicPluginTests (3), NotchHoverControllerTests (10), NotchStateMachineTests (14), SystemStatsServiceTests (5).
**Migration:** Complete. All `Boring*` classes/files renamed to `Notch*`/`Mach*`. Bundle ID `com.larsboes.machnotch`. Display name `mach.notch`. Plugin IDs `com.machnotch.*`. PluginSettings migration paths updated.
**GitHub Pages:** Enabled (workflow source). Sparkle `SUFeedURL` → `https://larsboes.github.io/mach-mono/appcast.xml` will resolve once `static.yml` workflow runs.

### Known Pre-Release TODOs

- [ ] First `static.yml` workflow run must succeed to publish appcast.xml to GitHub Pages
- [ ] Package.resolved synced between workspace and project (2026-05-02)
- [ ] No user data migration needed from `com.larsboes.boringnotch` bundle ID — fork was never released, so old Defaults domain has no user data

| Phase | Status | Summary |
|-------|--------|---------|
| 1, 1b, 2, 3, 5, 6, 6b, 7 | ✅ Shipped | Core plugins, API Hardening, AI Assist, Automation, Battery & Export |
| 4 — Animation + Arch Debt | ✅ Shipped | All 28 tasks done. Phase 14 sub-phases (14.1–14.4) merged. |
| 9 — Third-Party Distribution | Planned | `.machplugin` bundle format |
| 10 — Teleprompter Pro | Active | 10.0/10.4/10.7/10.8 shipped. Remaining: script library, voice scrolling, enhanced editor, closed display polish, screen sharing, detachable mode |
| 11 — Foundation Models | Planned | On-device AI via Apple FoundationModels (macOS 26+), streaming, structured generation |
| 12 — Audio Visualizer | Active | 12.1–12.6 shipped. Active CPU: ~11% (over 3% target — SCK overhead). |
| 13 — Notch Video Player | Planned (Long-term) | PiP-style video player via AVPlayer + browser integration. |
| 15 — Architecture Hardening | ✅ Complete | All 7 tasks done. BUGs 2–7 fixed. ISP narrowed service accessors shipped. |
| 16 — New Plugins | Active | **✅ HabitTracker** (shipped). Planned: SystemStats, PreventSleep, ExternalBrightness, ColorPicker, FocusMode, Downloads, MenuBar (absorber), Battery, DevActivity, Brief, MoodJournal — see specs below. |

### Phase 14 Status ✅

| Sub-phase | Status | Notes |
|-----------|--------|-------|
| 14.1 — Velocity-Dependent Springs | **Merged** | Fast flings overshoot, slow opens settle. Gesture-only (hover opens bypass). |
| 14.2 — Breathing Glow | **Killed** | Implemented but too subtle to notice; concept not compelling vs. real audio visualizer (Phase 12). |
| 14.3 — Gesture-Driven Progressive Open | **Merged** | Drag down on notch visually scrubs the open animation linearly with drag distance. Full velocity spring only on release. |
| 14.4 — Content Morphing | **Merged** | Re-enabled album art ghosting transition/matched geometry effect, now stable during transitions. |

**Latest architecture hardening commits:**

- `d277bd4` — snapshot before cleanup
- `0d7bd2b` — DI tightening + unsafe force-unwrap removal + singleton elimination work
- `89661d5` — project build wiring repair for LocalAPI/private sources
- `0b881d7` — architecture gate update for split settings files + core force-unwrap checks
- `cece6ed` — SOLID + DDD architecture cleanup (SRP extractions, PluginID, DisplayPrioritizer, HeaderButton)

---

## ✅ Shipped Work

| Task | Phase | Description |
|:-----|:------|:------------|
| 4.1 | Animation | Phase timing tuned — open 400→350ms, close 350→300ms for snappier feel. |
| 4.2 | Animation | Staggered header fade with blur — elements reveal sequentially during open. |
| 4.3 | Animation | Stagger interval widened 0.03→0.06s, shadow late-onset via `pow(2.5)`, border linger via `sqrt` curve. |
| 4.4 | Animation | Content choreography (open) — `ContentRevealModifier` drives continuous `contentProgress` environment key from 0→1. |
| 4.5 | Animation | Content choreography (close) — reverse path, `contentProgress` 1→0, automatic via modifier. |
| 4.6 | Animation | Replaced all `Task.sleep` phase transitions with `withAnimation` completion handlers — no more timing drift. |
| 4.7 | Arch Debt | `DefaultsNotchSettings` split from 457 lines into 5 ISP-compliant extension files. |
| 4.8 | Arch Debt | Duplicate stub files deleted across codebase. |
| 4.9 | Arch Debt | `NotchStateMachine` → `NotchAnimationStateProviding` protocol extraction for testability. |
| 4.10 | Arch Debt | All direct `Defaults[.]` reads routed through settings sub-protocols — no more raw UserDefaults in business logic. |
| 4.11 | Concurrency | `@MainActor` added to `NotificationCenterManager` — fixes implicit Sendable violations. |
| 4.12 | DI | `QuickLookService` injected via `QuickLookServiceProtocol` — was concrete dependency. |
| 4.13 | Docs | CLAUDE.md DDD table updated: `Plugins/Core/` reclassified as Application layer. |
| 4.14 | Cleanup | `sneakPeek` → `SneakPeek` case rename for Swift naming conventions. |
| 4.15 | Safety | Removed force-unwrap usage in core runtime UI paths (`ContentView`, `ContentView+Appearance`) and switched to safe optional handling. |
| 4.16 | DI | View layer no longer constructs fallback music services; `ContentView` now consumes injected `vm.musicService`. |
| 4.17 | DI / SOLID | `NotchServiceProvider` now exposes protocol-typed notes/clipboard/bluetooth services instead of concrete managers; consumers updated accordingly. |
| 4.18 | Architecture | Removed `NotchStateMachine.shared` and reduced singleton-default constructor usage in coordinator/view-model/service paths. |
| 4.19 | Build | Repaired Xcode target source wiring for LocalAPI/private files to keep build reproducible and green. |
| 4.20 | CI | Updated architecture check script allowlist for split settings files and added force-unwrap guardrails in core runtime paths. |
| 4.21 | Animation | Spring curve refinement — open: 0.32/0.92, close: 0.26/0.97, interactive: 0.20/0.94. Apple DI confidence. |
| 4.22 | Animation | Album art ghost fix — matchedGeometryEffect suppressed during transitions + lighting effect gated behind phase. |
| 4.23 | Animation | Shell-first content timeline — contentProgress delayed to 30%, ContentRevealModifier tightened, stagger cascade faster. |
| 4.24 | UX | Header controls gated on `phase == .open` — no accidental taps during transition. |
| 4.25 | Arch Debt | Removed unused `SoundService.shared` singleton (dead code). |
| 4.26 | Animation | HelloAnimation `Task.sleep(3.0)` replaced with `withAnimation` completion handler — eliminates timing drift on startup snake. |
| 4.27 | Domain Purity | Removed `import SwiftUI` from 5 Core/ domain files (`NotchStateMachine`, `NotchSettingsSubProtocols`, `MockNotchSettings`, `DefaultsNotchSettings`, `NavigationState`) — now compile with only `Foundation`/`Observation`/`Defaults`. |
| 4.28 | Docs | Fixed 5 doc discrepancies: ServiceContainer path in ARCHITECTURE.md, plugin registration location in PLUGIN_DEVELOPMENT.md, phantom Phase 8 in PRD, plugin count (8→12), NotchViewCoordinator status (legacy→active). Updated CLAUDE.md layer boundaries to distinguish domain vs coordinator files in Core/. |
| 4.29 | Sizing | `NotchSizeCalculator` restructured as single source of truth. `ClosedNotchInput` struct decouples calculator from services. `effectiveClosedNotchSize` moved from Observers to calculator. |
| 4.30 | Domain | `NotchAnimationStateProviding` + `createInput()` extracted from `NotchStateMachine.swift` to `ViewCoordinating.swift` (application layer). State machine is now domain-pure. |
| 4.31 | Safety | Force unwraps fixed in `Constants.swift`, `DownloadView.swift`, `BatteryService.swift`. |
| 4.32 | Cleanup | `NSObject` removed from `NotchViewModel`. NotificationCenter observers migrated to Combine publishers. |
| 4.33 | Cleanup | `NotchAnimations` collapsed from `@Observable` class to static enum. 29 unused `import Combine` removed. |
| 4.34 | DDD | **Directory restructure:** controllers/settings moved from `models/` → `Core/`. `SharingStateManager` → `Plugins/Services/`. `NotchViewModel` + extensions → new `ViewModel/` directory. `models/` now contains only pure data models. |
| 4.35 | Bounded Ctx | Plugin views consolidated: `components/Calendar/` → `CalendarPlugin/Views/`, `Weather` → `WeatherPlugin/Views/`, `Webcam` → `WebcamPlugin/Views/`, `Notifications` → `NotificationsPlugin/Views/`, `Music` → `MusicPlugin/Views/`. |
| 4.36 | DDD | `managers/` eliminated — all 19 files moved to `Plugins/Services/`. Single infrastructure layer. |
| 4.37 | Bounded Ctx | Shelf consolidated: 27 files from `components/Shelf/` → `ShelfPlugin/` (Models, Services, ViewModels, Views). General infrastructure services (ImageProcessing, QuickLook, etc.) → `Plugins/Services/`. |
| 4.38 | Cleanup | `Constants.swift` split into infrastructure constants + `SettingsTypes.swift` (Defaults.Serializable enums). |
| 4.39 | Rename | `NotchObserverSetup` → `NotchObserverManager` (reflects runtime controller role). |
| 4.40 | Bug Fix | Notch ears width desync fixed — `closedEarsActive` (debounced) could be true while `hasLiveActivity` (instant) was false during track transitions, causing narrow base + wide ears mismatch. Fix: force live-activity base size when ears active. |
| 5.1 | API | **Loopback binding** — `LocalAPIServer` now binds `127.0.0.1` only via `NWParameters.requiredLocalEndpoint`. |
| 5.2 | API | **Dynamic routing** — `APIRouteRegistrar` protocol (own file) enables plugins to register/unregister REST routes at runtime. Path params (`/plugins/{id}`) with proper 404 vs 405. |
| 5.3 | API | **Auth middleware** — Keychain-backed Bearer token in `APIAuthMiddleware` (`@unchecked Sendable`, `NSLock`). Denies on keychain failure (secure default). Enforced on all POST endpoints. |
| 5.4 | API | **Rate limiter** — `APIRateLimiter` (own file), sliding window 10 req/s per client. Periodic cleanup every 60s evicts stale clients — prevents unbounded memory growth. |
| 5.5 | API | **CLI companion** — `notchctl` shell script in `resources/scripts/` wrapping REST API (`open`, `close`, `display`, `music`, `teleprompter`). |
| 5.6 | API | **REST endpoints** — full coverage: notch state/open/close/toggle, plugin list/detail/toggle, music now-playing/play-pause/next/previous. All plugin accesses wrapped in `MainActor.run`. |
| 5.7 | API | **Event enrichment** — WebSocket payloads now include event-specific data (track title/artist/album, battery level/charging, notch phase) instead of generic metadata. |
| 6.1 | Plugin | **TeleprompterPlugin** — camera-adjacent script scrolling. 6 API endpoints (load/start/pause/stop/state/ai-assist). Timer only fires when `isScrolling == true` (no idle 60fps overhead). `didSet` observer manages lifecycle. |
| 6.2 | Plugin | **DisplaySurfacePlugin** — generic ambient display accepting text/progress/markdown via API. TTL support with cancellable `Task`. 3 endpoints (text/progress/clear). |
| 6.3 | Infra | **Plugin route registration** — `apiRouteRegistrar` exposed on `NotchServiceProvider`. Plugins register routes in `activate()`, unregister in `deactivate()`. |
| 6b.1 | AI | **3-tier AI stack** — `AIProvider` (transport, `Sendable`) → `AITextGenerationService` (domain protocol, `@MainActor`) → `ProviderBackedAIService` / `NoAITextGenerationService`. |
| 6b.2 | AI | **Deterministic fallback** — `NoAITextGenerationService` reports clean absence when AI is disabled or no provider is available. No install nag. |
| 6b.3 | AI | **Local providers** — Foundation Models is the zero-config default; oMLX is the explicit advanced localhost provider. Ollama support has been removed. |
| 6b.4 | AI | **AIManager DI** — no singleton access. `isEnabled` injected as closure from settings. Exposes `textGeneration: any AITextGenerationService`. |
| 6b.5 | AI | **Domain methods** — `rewrite(_:style:)` (4 styles), `summarize(_:)`, `section(_:)`, `draftIntro(topic:durationSeconds:)`. Prompt engineering encapsulated in `ProviderBackedAIService`. |
| 6b.6 | AI | **Teleprompter AI** — type-safe `TeleprompterAIAction` enum (refine/summarize/draft-intro). `DecodingError` returns 400 with valid options. |
| 6b.7 | AI | **Settings DI** — `isAIEnabled` added to `GeneralAppSettings` protocol + `DefaultsKeys.enableAI` + `MockNotchSettings`. No singleton reads. |
| 6b.8 | AI | **Service protocol** — `NotchServiceProvider.ai` typed as `any AITextGenerationService` (not concrete `AIManager`). `ServiceContainer` wires via `AIManager.textGeneration`. |
| 7.1 | Automation | **App Intents** — `OpenNotchIntent` + `CloseNotchIntent` routed through `NotificationCenter` bridge to `NotchViewModel`. No singleton coupling. |
| 7.2 | Automation | **URL scheme** — `machnotch://` open/close/toggle/plugins. Toggle checks `vm.notchState` for correct dispatch. Registered via `NSAppleEventManager` in AppDelegate. |
| 7.3 | Automation | **Intent bridge** — `NotchViewModel.setupIntentObservers()` observes `.openNotchIntent` / `.closeNotchIntent` on main queue with `[weak self]`. |
| 10.0 | Teleprompter | **Expanded panel redesign** — full-width two-column layout (editor left ~60%, control panel right ~40%). `TeleprompterControlPanel.swift` extracted. Speed controls, font size slider, 5 text color swatches (`PrompterColor` enum), AI actions, script info (word count, reading time, sections). Bottom action bar with Present CTA. |
| 10.3 | Teleprompter | **Voice visual feedback (partial)** — `MicrophoneMonitor` + linear gradient beam in `TeleprompterClosedView`. Responds to RMS level with spring animation. Remaining: radial arc shape, configurable color/opacity. |
| 10.4 | Teleprompter | **Countdown timer** — `CountdownState` (tick-based, configurable 0/3/5s) + `CountdownOverlayView` (cinematic scale+fade numbers, tap-to-cancel). Wired into `startPresentation()` flow. Overlay renders in closed view during countdown. |
| 10.7 | Teleprompter | **Hover-to-pause** — `.onHover` on `TeleprompterClosedView` pauses/resumes scrolling. `isHovering` state in `TeleprompterState`. Remaining: visual pause indicator overlay. |
| 10.8 | Teleprompter | **Keyboard shortcuts** — `TeleprompterShortcutHandler` with 5 user-configurable shortcuts (play/pause, speed up/down, reset, go home). Registered in plugin `activate()`, unregistered in `deactivate()`. |
| 10.10 | Teleprompter | **Improved closed display (partial)** — text centered under camera, full-width reading zone, voice beam, smooth per-pixel scroll. Remaining: karaoke fade, progress bar, section title, elapsed/remaining time. |
| 4.29 | Arch Debt | **SRP: TeleprompterTimerManager** — Extracted timer/mic lifecycle from `TeleprompterState` into dedicated `TeleprompterTimerManager`. State class now owns only scroll position, config, and domain logic. |
| 4.30 | Arch Debt | **SRP: DisplayPrioritizer** — Extracted display arbitration from `PluginManager` into pure `DisplayPrioritizer` struct. PluginManager delegates via `DisplayPrioritizer.highestPriority(among:)`. |
| 4.31 | Arch Debt | **SRP: HeaderButton** — Extracted `HeaderButton`/`HeaderActionButton` components from `NotchHeader`. Header reduced from 197→130 lines, eliminated 5x copy-paste button boilerplate. Sub-views: `leadingContent`, `notchOverlay`, `trailingControls`, `headerButtons`. |
| 4.32 | Arch Debt | **Clean Code: ContentView sub-views** — Extracted `notchBackground`, `glassOverlay`, `topEdgeLine` from 175-line body into computed views. |
| 4.33 | DDD | **PluginID enum** — Centralized all 30+ stringly-typed plugin identifiers into `PluginID` constants. All plugins, routers, event emitters, and settings views now use type-safe references. |
| 4.34 | DDD | **SneakContentType.isHUD** — Moved HUD-type check from free function in NotchHeader to computed property on enum (domain logic on domain type). |
| 4.35 | Clean Code | **DisplaySurfaceState** — Made `ttlTask` private, added `[weak self]` capture, added explicit `clear()` method. |
| 4.36 | Clean Code | **Named constants** — `TeleprompterState` magic numbers extracted: `endBuffer` (40px), `speedStep` (10), `speedMin` (10), `speedMax` (150). |
| 4.37 | Performance | **Background TimelineView gating** — `PluginMusicControlsView` `TimelineView(.animation)` now switches to static `HStack` when notch is closed. Eliminates 60fps background CPU burn. |
| 4.38 | Performance | **AVAudioRecorder lifecycle** — `MicrophoneMonitor` mic hardware release tied to `onDisappear`/`notchState` change. Orange dot no longer persists when teleprompter is paused. |
| 4.39 | Performance | **Eliminate `AnyView`** — Plugin views migrated from `AnyView` to type-specific wrappers, restoring SwiftUI structural identity for diff-based updates. |
| 4.40 | Performance | **Isolate high-frequency readers** — `elapsedTime` decoupled from `PluginMusicControlsView` into leaf `ScrubberPlayheadView`. Only playhead redraws at 60fps. |
| 4.41 | Performance | **GPU/CoreAnimation backoff** — Heavy `.blur(radius: 35)` and `.blendMode(.screen)` gated behind `!vm.phase.isTransitioning`. |
| 4.42 | Performance | **Background service suspension** — `BackgroundServiceRestartable` protocol + `NotchViewModel.phase` observer pauses `BatteryService`/`BluetoothManager` polling when notch closed. `NotchServiceProvider` consolidation. |
| 4.43 | Performance | **Teleprompter off-main parsing** — `TeleprompterState.text` `didSet` now parses sections via `Task.detached`, caching results instead of re-parsing 60× per second on MainActor. |
| 4.44 | Performance | **Aggressive @Observable Invalidation** — Decoupled high-frequency progress updates (currentTime/duration) into isolated publishers (Phase 2 efficiency). |
| 4.45 | Performance | **Window Coordinator Geometry** — Replaced 150ms polling loop with `CGDisplayRegisterReconfigurationCallback` hardware event handling. |
| 4.46 | Performance | **XPC Reconnection Backoff** — Implemented exponential backoff in `XPCHelperClient` to prevent CPU-intensive reconnection loops on crash. |

---

## Known Architecture Debt (Tracked)

Issues identified during comprehensive review (2026-03-08). Triaged 2026-05-02.

**Priority legend:** P1 = blocks a planned phase | P2 = degrades quality, fix when touching | P3 = cosmetic, defer

### ⚡ Quick Wins (low effort, unblocked — do these first)

| Item | Effort | Blocks |
|------|--------|--------|
| `MusicManager.isNowPlayingDeprecatedStatic` layer violation | Low | Nothing, quality |
| `NotificationsPlugin` concrete `ServiceContainer` cast | Low | Nothing, quality |

---

### [P3] DIP: NotchViewModel → concrete NotchViewCoordinator

**Severity:** Medium | **Blocks:** Nothing current | **Files:** 22 reference `NotchViewCoordinator` concretely | **Effort:** High

`NotchViewModel.coordinator` is typed as `NotchViewCoordinator` (concrete), not a protocol. Same for `ContentView`, `NotchContentRouter`, and `NotchHeader` via `@Environment`. Abstracting requires a `@Bindable`-compatible protocol, which SwiftUI doesn't natively support for existentials. Would require either:

- A `@Bindable`-aware wrapper type
- Or splitting coordinator into read-only protocol + mutation methods

**When to fix:** When `NotchViewCoordinator` needs to be testable in isolation, or if a second coordinator implementation is needed.

### [P1] ISP: Fat NotchServiceProvider (28 properties)

**Severity:** Medium | **Blocks:** Phase 9 (third-party plugins must not see internal services) | **Files:** `NotchServiceProvider.swift`, all plugin `activate()` methods | **Effort:** High
**Status:** ✅ Phase 1 addressed (2026-05-04)

A timer plugin needing only `sound` + `notifications` must depend on 28 services including `bluetooth`, `weather`, `brightness`. Should be split into focused sub-protocols:

- `MediaServices` (music, lyrics, sound)
- `SystemServices` (volume, brightness, battery)
- `StorageServices` (shelf, temporary files, sharing)
- `UIServices` (notifications, quicklook)
- `FullServiceProvider` (union for backward compat)

Five ISP-compliant accessors (`mediaServices`, `systemServices`, `storageServices`, `uiServices`, `pluginExtensionServices`) are now exposed on `PluginContext`. All 11 service-consuming built-in plugins have been migrated to use the narrowest accessor that covers their actual needs — zero plugins call `context.services` directly any more. For Phase 9, third-party plugins will receive a `PluginContext` whose `services` property is constrained to only the sub-protocol they declared at registration time.

**When to fix:** Phase 9 — wire the narrowed `services` type into external plugin context construction.

### [P3] ISP: Fat CoordinatorSettings

**Severity:** Low | **Blocks:** Nothing | **Files:** `NotchSettingsSubProtocols.swift:182-186` | **Effort:** Medium

`CoordinatorSettings` composes 6 sub-protocols (`GeneralAppSettings`, `HUDSettings`, `MediaSettings`, `AppearanceSettings`, `DisplaySettings`, `ShelfSettings`) but the coordinator only uses ~5 properties from them. Should be narrowed to actual usage.

**When to fix:** Next settings refactor pass or when adding new coordinator implementations.

---

> The items below were added during the 2026-03-23 architecture audit (3 parallel agents, 333 files analyzed).

### [P2 — Quick Win] Layer Violation: MusicManager.isNowPlayingDeprecatedStatic Leaks Across Layers

**Severity:** Medium | **Files:** 4 files outside `Plugins/Services/` | **Effort:** Low
**Status:** ✅ Fixed (2026-05-04)

`MusicManager.isNowPlayingDeprecatedStatic` (concrete infra type) is accessed directly in:

- `Core/DefaultsKeys.swift:164` — application layer calling into concrete infra
- `components/Settings/Views/MediaSettingsView.swift:31, 146` — presentation calling concrete infra
- `components/Onboarding/MusicControllerSelectionView.swift:16` — presentation calling concrete infra

All 4 used it to detect whether the NowPlaying API is deprecated (macOS version check). Fixed by routing deprecation checks through settings + `MediaControllerCapabilityProviding` and centralizing controller availability/default selection in `MediaControllerType` helpers.

**When to fix:** Phase 15 — low-effort, high-clarity win.

### [P2 — Quick Win] OCP Violation: NotificationsPlugin Casts to Concrete ServiceContainer

**Severity:** Medium | **Files:** `Plugins/BuiltIn/NotificationsPlugin/NotificationsPlugin.swift:51` | **Effort:** Low
**Status:** ✅ Fixed (2026-05-04)

Historical issue: downcasted protocol-typed `context.services` to concrete `ServiceContainer`. Current implementation resolves this by consuming `context.services.systemNotificationObserver` directly from service provider protocols, with no concrete cast.

**When to fix:** Phase 15 — 1-line fix, high DI cleanliness.

### [P2] SRP: NotchViewModel is a God Object (704 lines, 8+ responsibilities)

**Severity:** Medium | **Files:** `ViewModel/NotchViewModel.swift` + 4 extension files | **Effort:** High

Total 704 lines across `NotchViewModel.swift` (269), `+Observers.swift` (171), `+OpenClose.swift` (130), `+Hover.swift` (76), `+Camera.swift` (58). Responsibilities span: per-screen phase state, sizing delegation, hover detection, camera expansion, drop targeting, animation progress tracking, service dependencies, and observer lifecycle.

**Decomposition path:**

- `NotchPhaseCoordinator` — open/close logic, phase state, watchdog tasks
- `NotchAnimationOrchestrator` — contentRevealProgress, shellAnimationProgress
- `DropTargetingManager` — drag/drop state (`dragDetectorTargeting`, `generalDropTargeting`, `dropZoneTargeting`)
- `CameraFaceManager` — `isCameraExpanded`, `isRequestingAuthorization`
- `NotchViewModel` (residual, <150 lines) — sizing delegation, service access, wiring

**When to fix:** When any single responsibility needs independent testability, or when complexity slows feature work. Not urgent — extension files keep it manageable today.

### [P1] OCP Violation: PluginManager+ViewHelpers Requires Modifying for Every New Plugin

**Severity:** Medium | **Files:** `Plugins/UI/PluginManager+ViewHelpers.swift` | **Effort:** Medium

```swift
switch id {
case PluginID.music: if let p = plugin(id: id, as: MusicPlugin.self) { p.closedNotchContent() }
case PluginID.shelf: if let p = plugin(id: id, as: ShelfPlugin.self) { p.closedNotchContent() }
// ... 12+ more cases
}
```

Adding any new plugin requires modifying this switch in 3 places (closed, expanded, settings). The fix is type-erased view dispatch via `AnyNotchPlugin`, which already wraps plugins — it just doesn't expose a type-erased content method yet.

**When to fix:** Phase 9 (third-party plugins) requires this — external plugins cannot be added to a switch statement.

### [P1] ISP: Service Contracts Not Enforced at Compile Time

**Severity:** Low | **Files:** All `activate()` methods | **Effort:** High
**Status:** ✅ Convention enforced (2026-05-04)

ISP sub-protocols (`MediaServiceProvider`, `SystemServiceProvider`, etc.) exist on `NotchServiceProvider` but plugins receive the full union and can access any service. A `WeatherPlugin` can call `context.services.bluetooth` without restriction. Trust-based enforcement is fine for built-in plugins, but will be a liability for Phase 9 third-party plugins.

Built-in plugins now use the narrowest `PluginContext` accessor (`context.mediaServices`, `context.systemServices`, etc.) that covers their actual dependencies. No built-in plugin accesses `context.services` (the full union) directly. Compile-time enforcement for Phase 9 external plugins still requires `PluginContext` to be generic or carry a typed `services` property matching the declared sub-protocol.

**When to fix:** Phase 9 — external plugins must receive scoped service access.

### [P1] Hard-Coded Plugin Registration in AppObjectGraph

**Severity:** Low | **Files:** `AppObjectGraph.swift` | **Effort:** Medium
**Status:** ✅ Fixed — `PluginRegistry.makeBuiltInDescriptors()` centralises
default plugin metadata and factory closures; `AppObjectGraph` is no longer the
list owner. Bazel compiles built-ins as separate leaf targets, Soundscape is an
opt-in target, and runtime construction is strict on-demand.

Built-in plugins are registered as descriptors and instantiated only when a
specific plugin is enabled, displayed, configured, exported, or type-cast.

**When to fix:** Phase 9 — add capability-gating and discovery mechanism when external plugins are introduced.

---

---

## Phase 4 — Animation Polish + Architecture Debt (✅ Complete)

**Goal:** Dynamic Island-quality open/close transitions + clean architecture.

**Verified:** Zero files >300 lines, zero Defaults leaks, build green, 28 tests passing.

### Task 14: Spring curve refinement

**Status:** ✅ Complete

| Animation | Before | After | Change |
|-----------|--------|-------|--------|
| `open` | response: 0.38, damping: 0.82 | response: 0.32, damping: 0.92 | Less bounce, more confident — Apple DI feel |
| `close` | response: 0.35, damping: 0.92 | response: 0.26, damping: 0.97 | Quicker, near-critically damped retraction |
| `interactive` | response: 0.30, damping: 0.86 | response: 0.20, damping: 0.94 | Tight tracking, zero wobble |
| `staggered` | response: 0.32, damping: 0.86, delay: 0.06s | response: 0.30, damping: 0.88, delay: 0.05s | Tighter cascade |

### Task 19: Matched album art transition

**Status:** Partially implemented — matchedGeometryEffect wired but suppressed during transitions

`matchedGeometryEffect(id: "albumArt")` is connected on both `MusicLiveActivity` (closed) and `PluginAlbumArtView` (open). However, during `opening`/`closing` phases the effect is suppressed (namespace set to nil) because the container's spring animation conflicts with the geometry morph, causing stretch/ghost artifacts. Full morph will be re-enabled with Task 15 (gesture-driven progressive open) where the transition is scrubbed rather than spring-animated.

### Task 21: Animation artifact fixes + shell-first timeline

**Status:** ✅ Complete

**Album art ghost fix:**

- `matchedGeometryEffect` suppressed during transitions (both closed and open art views) — prevents spring-vs-morph conflict that caused stretch/jump.
- `albumArtBackground` lighting effect (blur/rotate/scale glow) suppressed during transitions — eliminates ghost decoration artifacts.

**Shell-first content timeline:**

- `contentProgress` starts at 30% of shell expansion (was 20%) — visible "shell leads, content follows" effect.
- `ContentRevealModifier` tightened: scale 0.94 (was 0.92), offset -3 (was -4), blur 8 (was 12). Subtler, more confident reveal.
- Stagger step reduced to 0.06 (was 0.08) for quicker cascade.

**Header/action gating:**

- Controls gated on `phase == .open` (fires after animation completes) instead of `notchState == .open` (fires at animation start). Prevents accidental taps and visual flicker during transition.

### Task 15: Gesture-driven progressive open (Future)

**Status:** Deferred — needs design

Replace fire-and-forget animations with continuous gesture-driven expansion. Notch height/width maps 1:1 to gesture translation — interruptible and scrubbable. Substantial refactor of `NotchViewModel+OpenClose`. Defer until Tasks 16-20 shipped.

---

## Phase 5 — Local API Server ✅

```
External clients (curl, Raycast, scripts, browser ext)
        │
        ▼
  LocalAPIServer (Network.framework, port 19384, loopback-only)
        │
        ├── REST routes → PluginManager / ServiceContainer
        │       (Bearer token auth on POST, rate limited 10 req/s)
        │
        └── WebSocket /events → PluginEventBus (enriched payloads)
```

**Endpoints:**

```
GET  /api/v1/notch/state              POST /api/v1/notch/open|close|toggle
GET  /api/v1/plugins                  GET  /api/v1/plugins/{id}
POST /api/v1/plugins/{id}/toggle
GET  /api/v1/music/now-playing        POST /api/v1/music/play-pause|next|previous
WS   /api/v1/events                   → notch.opened, music.changed, system.batteryChanged, ...
```

**CLI:** `notchctl open|close|display|music|teleprompter` — shell script in `resources/scripts/`.

---

## Phase 6 — API-Powered Plugins ✅

### TeleprompterPlugin — `Plugins/BuiltIn/TeleprompterPlugin/`

Camera-adjacent script scrolling for natural eye contact during video calls and presentations.

**Endpoints (self-registered on activate):**

```
POST /api/v1/teleprompter/load        → { text, speed?, fontSize? }
POST /api/v1/teleprompter/start|pause|stop
GET  /api/v1/teleprompter/state       → { position, isScrolling, text }
POST /api/v1/teleprompter/ai-assist   → { action: "refine" | "summarize" | "draft-intro" }
```

**Display:** `.high` when scrolling, `.normal` when paused, `nil` when empty.

### DisplaySurfacePlugin — `Plugins/BuiltIn/DisplaySurfacePlugin/`

Generic "dumb terminal" — renders whatever the API tells it to. No built-in logic.

**Endpoints (self-registered on activate):**

```
POST /api/v1/display/text             → { text, ttl? }
POST /api/v1/display/progress         → { label, value, ttl? }
POST /api/v1/display/clear
```

**Content types:** `.text`, `.markdown`, `.progress(label, value)`, `.keyValue([(String, String)])`, `.clear`

**Example integrations:**

| Script | Endpoint | Notch shows |
|--------|----------|-------------|
| CI watcher | `POST /display/progress {"label": "Build", "value": 0.73}` | Progress bar |
| Deploy script | `POST /display/text {"text": "Deployed v2.4.1 ✓", "ttl": 10}` | Temporary status |
| Meeting summarizer | `POST /display/text {"text": "Key: budget approved"}` | Real-time notes |

---

## Phase 6b — On-Device AI Assist ✅

```
Plugins  →  AITextGenerationService (domain: rewrite/summarize/section/draftIntro)
                    │
                    ├── ProviderBackedAIService (prompt engineering layer)
                    └── NoAITextGenerationService (deterministic fallback)
                            │
                    AIProvider (transport: generate)
                            ├── FoundationModelsProvider (#available macOS 26) — PRIMARY
                            └── OMLXProvider (opt-in, Advanced local provider)
```

**Hard rule:** AI is assistive only. No core plugin workflow depends on AI availability.

**DI:** `NotchServiceProvider.ai → any AITextGenerationService`. `ServiceContainer` wires via `AIManager(isEnabled: { settings.isAIEnabled }).textGeneration`. No singletons.

### AI Provider Strategy

- **Primary:** Apple Foundation Models (macOS 26+). On-device, zero config, zero install, fully private. Covers the teleprompter sweet spot (summarization, rewriting, extraction).
- **Optional/Advanced:** oMLX for power users who want larger/specialized local MLX models. Hidden behind "Advanced AI Settings" toggle. Not registered unless explicitly enabled.
- **Fallback:** `NoAITextGenerationService` — clean degradation. On macOS <26 or unsupported hardware, AI features simply don't appear in the UI. No install messaging.

**Migration:** Ollama support has been removed. Foundation Models becomes the sole default provider; oMLX is the planned advanced local provider.

### Remaining AI plugin opportunities

- **DisplaySurface:** summarize long pushed content into notch-safe cards
- **Notifications:** merge notification bursts into "what matters now" digests
- **Clipboard:** rewrite/clean copied text, extract action items
- **Calendar:** compact "next up" meeting briefs

---

## Phase 7 — Automation & Integrations ✅

**App Intents:** `OpenNotchIntent`, `CloseNotchIntent` — Shortcuts-compatible, NotificationCenter bridge.
**URL Scheme:** `machnotch://open|close|toggle|plugins?id=...` — registered via `NSAppleEventManager`.
**Bridge:** `NotchViewModel.setupIntentObservers()` on main queue with `[weak self]`.

---

## Phase 9 — Third-Party Plugin Distribution

**Goal:** `.machplugin` bundle format + plugin discovery UI.

**Separate design document when Phase 7 is complete.**

Requirements: signed Swift package bundles, permission manifests, approval UI, plugin browser in Settings, `~/Library/Application Support/machNotch/Plugins/` discovery.

---

## Phase 10 — Teleprompter Pro (Moody-Class Upgrade)

**Goal:** Transform the basic teleprompter into a professional-grade, voice-aware prompter with Apple Foundation Models integration. Competitive reference: [Moody](https://moody.mjarosz.com/) — the notch teleprompter benchmark.

**Design Principle:** The notch is the most camera-adjacent display surface on any MacBook. A teleprompter here is *the* killer feature — but only if it's polished enough that creators actually use it daily.

### Current State Assessment

The existing teleprompter (Phase 6) is functional but bare-bones:

- Timer-driven scroll at fixed px/s
- Basic `TextEditor` for script input (360px wide in a 740px notch — wastes half the space)
- Play/pause/stop + basic speed controls
- Paste from clipboard
- AI assist (refine/summarize/draft-intro) currently has no default provider after the M0 cleanup; next step is Foundation Models
- Closed view: centered text with voice beam + hover-to-pause (functional)
- No script management, no mode selection, no progress indicators

**What's missing for professional use:** script library, voice-driven scrolling, visual feedback polish, calibration, rich editing, display customization, detachable mode, and on-device AI via Foundation Models.

### 10.0 — Expanded Panel Redesign ✅

Full-width two-column layout (editor ~60% left, control panel ~40% right, action bar bottom). Files: `TeleprompterExpandedView.swift` (rewritten), `TeleprompterControlPanel.swift` (new). See shipped work table for details.

### 10.1 — Script Library

**Status:** Planned | **Priority:** P1

Save, load, and manage named scripts. The dropdown in the expanded panel header switches between scripts.

**Implementation:**

- `TeleprompterScriptLibrary` — manages saved scripts as `[ScriptEntry]`
- `ScriptEntry`: `id: UUID`, `name: String`, `text: String`, `createdAt: Date`, `lastUsedAt: Date`
- Storage: `PluginSettings` (JSON-encoded array), persists across app restarts
- UI: dropdown menu in expanded panel header showing script names + "New Script" / "Delete" options
- Auto-save: current script saves on every edit (debounced 1s) and on notch close
- Import: drag-and-drop `.txt`/`.md`/`.rtf` onto editor creates a new script entry
- Limit: 50 scripts max (warn at 40, hard cap at 50)

### 10.2 — Voice-Driven Scrolling ("Flow Mode")

**Status:** Planned | **Priority:** P2

Use `AVAudioEngine` + `SFSpeechRecognizer` to match scroll speed to speaking pace. When the speaker pauses, scrolling pauses. When they speed up, scrolling accelerates.

**Implementation:**

- `VoiceScrollEngine` — new file in `TeleprompterPlugin/`
- Taps system microphone via `AVAudioEngine.inputNode`
- Uses `SFSpeechRecognizer` for real-time speech-to-text
- Matches recognized words against script text to determine position
- Falls back to audio energy level (RMS) when speech recognition unavailable
- Adjustable microphone sensitivity slider in settings
- Permission request: microphone access (graceful degradation if denied)

**Algorithm:**

```
1. Continuous speech recognition → word stream
2. Fuzzy-match recognized words against script text (Levenshtein / sliding window)
3. When match found → snap scroll position to matched word's Y offset
4. When no speech detected for >1s → pause scrolling
5. Fallback: if speech recognition off, use audio RMS level to modulate speed
```

**Key constraint:** Flow Mode is *optional*. Manual scroll (current timer-based) remains the default. User toggles between modes in the expanded panel's control column.

**Mode UI:** Radio toggle in control panel — `○ Manual  ○ Voice (Flow)`. Voice mode shows a microphone sensitivity slider below. Manual mode shows speed controls.

### 10.3 — Voice Visual Feedback

**Status:** Partially implemented (basic beam exists in `TeleprompterClosedView`) | **Priority:** P2

Visual beam/glow emanating from the notch that responds to microphone input level. Helps speakers monitor their volume without looking away from camera.

**Current state:** `MicrophoneMonitor` + basic linear gradient beam already exist in `TeleprompterClosedView`. Needs polish.

**Remaining work:**

- Refine beam shape: radial arc rather than rectangular gradient
- Color configurable: blue-purple (default), green, amber
- Opacity configurable (settings)
- Smooth animation curves (current spring is decent, may need tuning)
- On/off toggle in settings

### 10.4 — Countdown Timer ✅

Cinematic 3-2-1 countdown before scrolling. Configurable (0/3/5s). Files: `CountdownState.swift`, `CountdownOverlayView.swift`. Wired into `startPresentation()` flow.

### 10.5 — Built-In Script Editor (Enhanced)

**Status:** Planned | **Priority:** P1

The left column of the expanded panel is the editor. Enhance beyond basic `TextEditor`.

**Features:**

- Full available height (no fixed 140px) — editor grows with the notch
- Markdown-aware rendering: `## Section` headers render as visual dividers in a preview mode
- Section navigation: click section headers to jump (in preview mode)
- Undo/redo support (native `TextEditor` undo, plus AI action undo)
- Import from file (`.txt`, `.md`, `.rtf`) via drag-and-drop or file picker
- Auto-save to script library (debounced 1s)
- Edit/Preview toggle: switch between editing raw text and reading formatted preview

### 10.6 — Scroll Speed Calibration

**Status:** Planned | **Priority:** P2

Guided calibration flow where the user reads a sample text at their natural pace. The system measures their reading speed and sets the default accordingly.

**Implementation:**

- Calibration wizard accessible from settings (or first-run)
- Shows sample paragraph in the notch area
- User reads aloud (or reads silently and taps when done)
- Calculates words-per-minute → maps to px/s scroll speed
- Stores calibrated speed as default
- Preview: real-time scroll speed preview during calibration

### 10.7 — Hover-to-Pause ✅

`.onHover` pauses/resumes scrolling. Remaining: visual pause indicator overlay.

### 10.8 — Keyboard Shortcuts ✅

5 user-configurable shortcuts (play/pause, speed up/down, reset, go home) via `KeyboardShortcuts` framework. File: `TeleprompterShortcutHandler.swift`. Registered in plugin lifecycle.

### 10.9 — Display Customization

**Status:** Planned | **Priority:** P1

Inline in the expanded panel's control column (not buried in settings):

- **Font size:** slider/stepper (10–40pt), live preview in editor
- **Text color:** 5 preset swatches (white, warm white, yellow, green, cyan) — common prompter colors. Dot selector, not a full color picker.
- **Background opacity:** slider (0–100% behind text for readability in closed view)
- **Mirror mode:** toggle — horizontally flip text (for physical teleprompter setups with beam splitters)
- **Line highlight:** toggle — current line full opacity, surrounding lines fade (karaoke-style)
- **Margin/padding:** compact slider for text inset in closed view

### 10.10 — Improved Closed-Notch Display

**Status:** Partially implemented | **Priority:** P0

The closed view already has centered text, voice beam, and hover-to-pause. Remaining:

**Improvements:**

- Show 2–3 lines: current line bold/bright, next lines progressively dimmer (karaoke fade, see 10.9 line highlight)
- Progress indicator: subtle bar at the bottom showing position in script (0–100%)
- Current section title shown if script uses `##` headers (small, top-right of reading zone)
- Elapsed time / remaining time (small, non-distracting, bottom corners)
- Smooth per-pixel scroll already works — verify no line-snapping at any speed

### 10.11 — Screen Sharing Safety

**Status:** Planned | **Priority:** P1

The teleprompter text should be invisible during screen sharing — the speaker sees it, but their audience doesn't.

**Implementation:**

- Use `NSWindow.sharingType = .none` on the teleprompter overlay window
- This excludes the window from screen capture, screenshots, and screen sharing
- Toggle in settings: "Hide from screen sharing" (default: on)
- Alternative: detect active screen sharing via `CGDisplayStream` and auto-hide

### 10.12 — Detachable Floating Mode

**Status:** Planned | **Priority:** P3

For external displays (no notch), desktop recording, or dual-screen setups where the user wants the prompter elsewhere.

**Implementation:**

- Separate `NSPanel` window (`.nonActivating`, `.floating`, draggable, resizable)
- Mirrors `TeleprompterState` — same scroll engine, same text, same controls
- Shares all display settings (font, color, opacity, line highlight)
- Inherits `sharingType = .none` from 10.11
- Toggle: "Detach to floating window" button in expanded panel or settings
- When detached: closed-notch teleprompter view hides, floating window takes over
- When reattached: floating window closes, notch resumes
- Keyboard shortcuts work regardless of attached/detached mode

---

## Phase 11 — Apple Foundation Models Integration

**Goal:** First-class on-device AI via Apple's `FoundationModels` framework (macOS 26+). Zero config, zero external dependencies, fully private.

**Why this matters:** The current AI stack has been cleaned up so no provider is selected by accident. Foundation Models is built into macOS 26 — it just works when available. This makes AI features accessible to supported users without installing a separate local LLM app.

### Architecture

The existing 3-tier AI stack (`AIProvider` → `AITextGenerationService` → `ProviderBackedAIService`) was designed for this. `FoundationModelsProvider` becomes the sole default provider.

```
AIManager
├── FoundationModelsProvider  ← PRIMARY (macOS 26+, zero config, on-device)
├── OMLXProvider              ← OPT-IN (Advanced local provider, power users only)
└── NoAITextGenerationService ← FALLBACK (macOS <26 or unsupported hardware)

Default: Foundation Models (if macOS 26+) > NoAI
Advanced: User explicitly enables oMLX → oMLX (if running) > Foundation Models > NoAI
```

### 11.1 — FoundationModelsProvider

**Status:** Planned

```swift
// Gated behind #available(macOS 26, *)
@available(macOS 26, *)
struct FoundationModelsProvider: AIProvider {
    let id = "foundation-models"
    let name = "Apple Intelligence"

    var isAvailable: Bool {
        get async {
            SystemLanguageModel.default.availability == .available
        }
    }

    func generate(prompt: String, config: AIGenerationConfig) async throws -> String {
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
```

**Key decisions:**

- New `LanguageModelSession` per call (stateless provider, session management is caller's job)
- Map `AIGenerationConfig.temperature` etc. where possible (Foundation Models may have limited knobs)
- Availability check via `SystemLanguageModel.default.availability`
- Errors: map `LanguageModelSession` errors to `AIError` cases

### 11.2 — Streaming Support

**Status:** Planned

The current `AIProvider.generate()` returns a complete `String`. Add streaming variant for responsive UX.

```swift
protocol AIProvider: Sendable {
    // ... existing ...
    func generateStream(prompt: String, config: AIGenerationConfig) -> AsyncThrowingStream<String, Error>
}
```

**Foundation Models streaming:**

```swift
func generateStream(prompt: String, config: AIGenerationConfig) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        Task {
            let stream = session.streamResponse(to: prompt)
            for try await partial in stream {
                continuation.yield(partial.content ?? "")
            }
            continuation.finish()
        }
    }
}
```

**Impact on teleprompter:** AI-assisted rewriting shows text appearing progressively instead of a loading spinner → results dialog.

### 11.3 — Structured Generation for Teleprompter

**Status:** Planned

Use `@Generable` for type-safe AI outputs instead of parsing raw text.

```swift
@available(macOS 26, *)
@Generable
struct TeleprompterScript {
    @Guide(description: "The rewritten script text, natural spoken language")
    var text: String

    @Guide(description: "Estimated reading time in seconds")
    var estimatedDurationSeconds: Int

    @Guide(description: "Section markers with timestamps", .maximumCount(10))
    var sections: [ScriptSection]
}

@available(macOS 26, *)
@Generable
struct ScriptSection {
    var title: String
    var startWord: Int
}
```

**Benefits:**

- Guaranteed valid output structure (no parsing failures)
- Section markers auto-generated → navigation in editor for free
- Duration estimate → progress bar accuracy

### 11.4 — Expanded AI Actions

**Status:** Planned

Beyond the current refine/summarize/draft-intro, add:

| Action | Description | Use Case |
|--------|-------------|----------|
| `expandBullets` | Expand bullet points into full spoken paragraphs | Turning notes into a script |
| `simplify` | Reduce reading level, shorter sentences | Accessibility, non-native speakers |
| `addPauses` | Insert `[PAUSE]` markers at natural break points | Pacing guidance |
| `translateStyle` | Convert between formal/casual/technical | Audience adaptation |
| `timeToTarget` | Rewrite to hit a target duration (e.g., "make this a 2-minute script") | Time-constrained presentations |

**Implementation:** New cases in `TeleprompterAIAction` enum + corresponding prompts in `ProviderBackedAIService`. Foundation Models handles these well since they're summarization/extraction tasks (its sweet spot per Apple's guidance — not world knowledge).

### 11.5 — Smart Instructions for Foundation Models

**Status:** Planned

Use `LanguageModelSession(instructions:)` for teleprompter-specific system prompts:

```swift
let session = LanguageModelSession(
    instructions: """
    You are a teleprompter script assistant. Your outputs will be read aloud \
    on camera. Write in natural spoken language — short sentences, clear \
    transitions, no jargon unless the speaker's context requires it. \
    Never include stage directions or formatting instructions.
    """
)
```

### 11.6 — Provider Registration Overhaul

**Status:** Planned

Replace current empty-default `AIManager.init()` with Foundation Models-first strategy:

```swift
init(isEnabled: @escaping () -> Bool = { true }) {
    self.isEnabledProvider = isEnabled

    // Primary: Foundation Models (macOS 26+, zero config)
    if #available(macOS 26, *) {
        registerProvider(FoundationModelsProvider())
        activeProviderId = "foundation-models"
    }
}

/// Called when user enables oMLX in Advanced AI Settings
func enableOMLX(host: String = "http://127.0.0.1:8000", model: String? = nil) {
    registerProvider(OMLXProvider(host: host, model: model))
    activeProviderId = "omlx"
}

func disableOMLX() {
    providers.removeValue(forKey: "omlx")
    // Fall back to Foundation Models or NoAI
    if #available(macOS 26, *) {
        activeProviderId = "foundation-models"
    } else {
        activeProviderId = nil
    }
}
```

**Feature gating:** On macOS <26 without oMLX enabled, AI action buttons simply don't render. No error states, no "upgrade macOS" messaging — the feature just isn't there. Clean absence > broken presence.

**Availability resilience:** Foundation Models may report `.available` at init but fail later (model downloading, etc.). The `generate()` call catches errors and surfaces them per-request — no automatic fallback to oMLX unless user explicitly configured it.

### 11.7 — AI Settings UI

**Status:** Planned

**Main AI Settings (visible to all users on macOS 26+):**

- AI enable/disable toggle
- AI availability indicator (green dot = Foundation Models ready)
- "Test AI" button — sends a sample prompt and shows response

**Advanced AI Settings (collapsed/hidden section):**

- "Use advanced local provider (oMLX)" toggle — off by default
- When enabled:
  - oMLX host (default: `127.0.0.1:8000`)
  - Optional model id
  - Connection status indicator
  - "oMLX takes priority over Foundation Models when enabled and reachable" note
- Link to oMLX docs/download

**On macOS <26:** AI settings section shows "AI features require macOS 26 or later" with the Advanced section still available for oMLX opt-in.

---

## Phase 10/11 Implementation Order

Prioritized by user impact and dependency chain:

| Priority | Task | Depends On | Impact |
|----------|------|------------|--------|
| **P0** | 10.10 Improved closed display | — | Core reading experience |
| **P1** | 10.1 Script library | — | Script management, persistence |
| **P1** | 10.5 Enhanced editor | — | Content creation flow |
| **P1** | 10.9 Display customization | — | Personal preference |
| **P1** | 10.11 Screen sharing safety | — | Professional use case |
| **P1** | 11.1 FoundationModelsProvider | — | Zero-config AI for all users |
| **P1** | 11.6 Foundation Models default registration | 11.1 | Zero-config provider selection |
| **P2** | 10.2 Voice-driven scrolling | AVAudioEngine, SFSpeechRecognizer | Flagship differentiator |
| **P2** | 10.3 Voice visual feedback | 10.2 | Polish on top of voice |
| **P2** | 10.6 Scroll speed calibration | — | Nice-to-have |
| **P2** | 11.2 Streaming support | 11.1 | Better AI UX |
| **P2** | 11.3 Structured generation | 11.1 | Better AI output quality |
| **P3** | 10.12 Detachable floating mode | 10.11 | External displays, dual-screen |
| **P3** | 11.4 Expanded AI actions | 11.1 | More AI capabilities |
| **P3** | 11.5 Smart instructions | 11.1 | Better AI context |
| **P3** | 11.7 AI settings UI | 11.1 | Power user config |

---

## Phase 12 — Audio Visualizer (Extended Notch)

**Goal:** Replace the fake 4-bar spectrum with a real, audio-reactive visualizer that extends the closed notch downward. Beautiful enough that users leave it on permanently.

**Why:** The current `AudioSpectrum` is a `CAKeyframeAnimation` with random values — not connected to audio at all. macOS's own notch music indicator is similarly basic. A real audio-reactive visualization is the single highest-impact visual upgrade for the most-used plugin (Music).

**Design Principle:** The notch should feel alive when music plays — like the music is physically emanating from it. Not a gimmick, an ambient display that rewards peripheral attention.

### Architecture

```
ScreenCaptureKit (system audio)
        │ CMSampleBuffer (audio frames)
        ▼
AudioCaptureService (protocol-based)
        │ Float array (raw PCM)
        ▼
AudioFFTProcessor (Accelerate vDSP)
        │ [Float] frequency magnitudes (32-64 bands)
        ▼
AudioVisualizerPlugin
        │ VisualizationMode enum
        ▼
VisualizerRenderer (Metal / Core Animation)
        │ Rendered frames
        ▼
closedNotchContent() → extended notch view
```

### 12.1 — Audio Capture Service

**Status:** ✅ Done | **Priority:** P0

**Protocol:**

```swift
protocol AudioCaptureServiceProtocol: Sendable {
    var audioBuffer: AsyncStream<[Float]> { get }
    var isCapturing: Bool { get }
    func startCapture() async throws
    func stopCapture() async
}
```

**Implementation:** `ScreenCaptureKitAudioService`

- Uses `SCStreamConfiguration` with `capturesAudio = true`, `excludesCurrentProcessAudio = false`
- Video capture disabled (`width = 2, height = 2, minimumFrameInterval = CMTime(1, 1)`) — audio-only workaround since SCK requires a display
- `SCStreamOutput` delegate receives `CMSampleBuffer` → extract `AudioBufferList` → convert to `[Float]`
- One-time `SCShareableContent.current` to pick default display (required by API, but we only want audio)
- Permission: system dialog on first use. No entitlement needed for own audio capture
- Publishes raw PCM frames via `AsyncStream` at audio sample rate

**Fallback:** If user denies screen recording permission, `MockAudioCaptureService` publishes energy-based random data (current behavior, elevated slightly). Existing `AudioSpectrum` still works.

**Key constraint:** `ScreenCaptureKit` requires screen recording permission. Falls back to `MockAudioCaptureService` if permission denied.

### 12.2 — FFT Processor

**Status:** ✅ Done | **Priority:** P0

```swift
@MainActor
final class AudioFFTProcessor {
    private let fftSetup: vDSP_DFT_Setup
    private let bandCount: Int

    func process(_ samples: [Float]) -> [Float]  // Returns normalized magnitudes per band
}
```

- Uses `vDSP_DFT_zop_CreateSetup` for FFT (1024-sample window, Hann windowing)
- Maps FFT output to `bandCount` frequency bands (default 32, configurable 16/32/64)
- Logarithmic frequency scaling (more resolution in bass/mids, less in highs — matches human perception)
- Temporal smoothing: `newValue = α * raw + (1 - α) * previous` (α = 0.3, configurable)
- Peak detection with decay: peaks hold for ~200ms then fall at constant rate
- Output: `[Float]` array of 0.0–1.0 normalized magnitudes
- Processing on background thread, results delivered to MainActor

### 12.3 — Visualization Modes

**Status:** ✅ Fixed — Generative ambient (`.simulated` mode) works. Audio Reactive (`.realAudio` mode) was broken due to missing sample accumulation in FFT processor (SCK delivers 512-sample buffers; FFT needed 1024). Fixed with overlap accumulation. Waveform/gradient/radial modes deferred. | **Priority:** P1

**Enum:**

```swift
enum VisualizationMode: String, Codable, CaseIterable {
    case spectrumBars    // Classic equalizer bars
    case waveform        // Oscilloscope-style continuous line
    case flowingGradient // Abstract color gradient morphing with audio
    case radialSpectrum  // Circular arrangement around notch center
}
```

**Spectrum Bars (default):**

- 16–32 vertical bars across notch width, rounded caps
- Height maps to frequency magnitude
- Gradient color: album art dominant color → accent color fallback
- Smooth spring animation between values (not jerky)
- Bar width and gap auto-calculated from available width

**Waveform:**

- Continuous `Path` representing audio waveform
- Centered horizontally, amplitude maps to vertical displacement
- Stroke with gradient (album art colors)
- Smooth interpolation between sample points (Catmull-Rom)

**Flowing Gradient:**

- `MeshGradient` (macOS 26+) or layered `LinearGradient` fallback
- Control points shift based on frequency band energy
- Low frequencies drive slow, large movements; highs drive small, fast ripples
- Colors extracted from album art via `ColorThief`-style dominant color extraction
- Most ambient/subtle mode — designed for peripheral attention

**Radial Spectrum:**

- Frequency bars arranged in a semicircle emanating from notch center bottom
- Inner radius = notch corner radius, outer radius = inner + magnitude * maxHeight
- Each bar is a wedge/arc segment
- Looks like sound waves radiating from the notch

### 12.4 — Extended Notch Display

**Status:** ✅ Done — `AmbientGlowVisualizer` renders below closed notch via `ContentView.ambientVisualizerOverlay`. Height configurable 80–220px. | **Priority:** P0

The visualizer extends the closed notch downward by a configurable height (20–60px, default 30px).

**Integration with existing architecture:**

- `AudioVisualizerPlugin.displayRequest` sets `preferredHeight` when music is playing
- `NotchStateMachine` already supports variable closed-notch height via display requests
- The extension area renders below the standard notch content (album art, controls)
- Smooth height animation when visualizer activates/deactivates (spring curve matching Phase 4 values)

**Layout:**

```
┌──────────────────────┐
│   ▓▓▓▓ NOTCH ▓▓▓▓   │  ← Standard closed notch (album art, title, controls)
├──────────────────────┤
│ ▎▌█▌▎▍▊▎▌█▌▎▍▊▎▌█▌ │  ← Extended area: visualizer (20-60px)
└──────────────────────┘
```

**Renderer choice:**

- **Primary:** `CALayer`-based (Core Animation) — matches existing `AudioSpectrum` pattern, good performance
- **Upgrade path:** Metal shader for Flowing Gradient and Radial modes (GPU-accelerated, <1% CPU)
- **Not SwiftUI:** Too expensive for 30fps continuous animation

### 12.5 — Album Art Color Extraction

**Status:** ✅ Done — `MusicArtworkService.avgColor` extracts dominant color, published via `avgColorPublisher`. Used in visualizer theming and closed-notch tint. | **Priority:** P2

Extract dominant colors from current album art for visualizer theming.

```swift
protocol ColorExtractionServiceProtocol {
    func dominantColors(from image: NSImage, count: Int) async -> [NSColor]
}
```

- K-means clustering on downscaled image (32x32) for speed
- Cache per track (invalidate on track change)
- Returns ordered by prominence: primary, secondary, accent
- Fallback: system accent color when no album art

### 12.6 — Visualizer Settings

**Status:** ✅ Done — Shipped in `MediaSettingsView`. | **Priority:** P1

| Setting | Type | Default | Shipped |
|---------|------|---------|---------|
| Visualizer enabled | Toggle | Off | ✅ `ambientVisualizerEnabled` |
| Mode | Picker | Generative | ✅ `ambientVisualizerMode` (.simulated / .realAudio) |
| Extended height | Slider | 110px | ✅ `ambientVisualizerHeight` (80–220px) |
| Color source | Picker | Album Art | ⏳ Deferred — `coloredSpectrogram` toggle exists; 3-way picker not built |
| Sensitivity | Slider | 0.5 | ✅ `visualizerSensitivity` → maps to FFT smoothingFactor |
| Show when paused | Toggle | Off | ✅ `visualizerShowWhenPaused` |
| Band count | Segmented | 32 | ✅ `visualizerBandCount` (16/32/64, shown for realAudio mode only) |

**API endpoints (self-registered):**

```
GET  /api/v1/visualizer/state     → { mode, isActive, sensitivity }
POST /api/v1/visualizer/mode      → { mode: "spectrumBars" | "waveform" | ... }
POST /api/v1/visualizer/toggle
```

### 12.7 — Performance Budget

**Measured (2026-03-16, M-series MacBook, music playing, realAudio mode):**

| State | CPU | Memory | Energy Impact |
|-------|-----|--------|---------------|
| Idle / closed (no music) | 3% | ~59MB | Low ✅ |
| Active visualizer (music + realAudio mode) | ~11% | ~159MB | High ⚠️ |

**Original targets vs reality:**

| Component | Target | Actual | Notes |
|-----------|--------|--------|-------|
| Audio capture (SCK) | <0.5% | ~2-3% | SCK has unavoidable framework overhead |
| FFT processing | <0.5% | ~1% | 1024-sample vDSP at 21fps on MainActor |
| Canvas render | <2% | ~3-4% | SwiftUI Canvas at 8fps; not Metal |
| **Total delta** | **<3%** | **~8%** | Over target |

**Optimizations shipped:**

- SCK audio batched to 2048-sample chunks before MainActor dispatch (86fps → 21fps Task creation)
- FFT hop size 2048 (~21fps processing, down from naive 43fps)
- SCK only started when `ambientVisualizerEnabled && mode == .realAudio` (no capture in simulated mode)
- Canvas at 8fps, stride-5 wave paths, 30-step orbits, 8 particles (down from 20fps/stride-3/60-step/16)
- Energy multipliers tuned (bass 6x→2.5x, orbit 5x→1.5x) to prevent visual chaos at real audio levels

**Known ceiling:** The ~100MB memory delta and ~2-3% SCK CPU cost are ScreenCaptureKit framework overhead — internal buffers, video pipeline stub, etc. Not reducible without switching capture method.

**Long-term fix (not yet implemented):** Replace SCK with the macOS 14.2+ system audio tap API (`AudioObjectCreateIOProcID` on output device). No video pipeline, no 100MB allocation, estimated <0.5% CPU. Worth a dedicated branch when targeting <5% active CPU.

- All processing paused when music is paused (unless "Show when paused" enabled)
- Visualizer hidden when notch is expanded (full panel open)

---

## Known Bugs

### BUG-1 — Audio Visualizer (realAudio mode) Not Reactive

**Status:** ✅ Fixed

**Root cause:** `AudioFFTProcessor.process` accumulated samples until `count >= hopSize` (2048) before processing, but SCK delivers ~512-sample buffers, so the guard was never satisfied. (`hopSize = 2048`, not `fftSize = 1024` as described in an earlier version of this note.)

**Secondary issue:** `AudioSpectrum.updateBands` had `peak > 0.08` threshold that silenced quiet audio in the 4-bar notch indicator. Lowered to `0.01`.

**Fix:**

- `AudioFFTProcessor.swift` — Added `sampleAccumulator: [Float]`. `process()` now appends samples and processes once ≥ `hopSize` (2048) are accumulated. Uses a sliding window with 2048-sample hop for ~21fps update rate at 44.1 kHz. Accumulator is capped to prevent memory growth.
- `MusicVisualizer.swift` — Lowered `peak` threshold from `0.08` → `0.01`.

---

### BUG-2 — Notch Expands Horizontally ~3s Then Snaps Back

**Status:** ✅ Fixed (Phase 15.1 — `NotchSizeCalculator.swift:95` gates ear-width on `input.phase == .closed`)

**Symptom:** Notch randomly widens (horizontally) for ~3 seconds then returns to normal size.

**Root cause (traced):** `KeyboardShortcutCoordinator` opens the notch and schedules a `Task.sleep(3s)` auto-close (`KeyboardShortcutCoordinator.swift:100`: `try? await Task.sleep(for: .seconds(3))`). During those 3 seconds, `NotchObserverSetup` fires a `hideOnClosed` change (triggered by `FullscreenMediaDetector.fullscreenStatus`). This causes `NotchViewModel.effectiveClosedNotchSize` to recalculate — and if `isMusicActive || isFaceActive` is true, extra width is added/removed with a `.smooth` animation. The 3s timer then fires `viewModel.close()` snapping it back.

**Key files:**

- `KeyboardShortcutCoordinator.swift:100` — `try? await Task.sleep(for: .seconds(3))` auto-close
- `NotchViewModel+Observers.swift:16–36` — `hideOnClosed` setter triggers `.smooth` animation
- `NotchViewModel+OpenClose.swift:65–68` — `effectiveClosedNotchSize` snapshot taken at close-start
- `Core/NotchObserverSetup.swift:42–73` — hideOnClosed observer loop (unstructured Task, no cancellation)

**Fix direction (two options, pick one):**

1. **Suppress width recalculation during keyboard open:** Gate `effectiveClosedNotchSize` width additions on `phase == .closed` — don't add ear-width while notch is open/transitioning
2. **Cancel hideOnClosed debounce on `.opening`:** `NotchViewModel+OpenClose.swift` already cancels `hideOnClosedDebounceTask` on `open()` — verify this fires before the fullscreen observer can race in

---

### BUG-3 — AudioFFTProcessor Force Unwrap Crash Risk

**Status:** ✅ Fixed (Phase 15.4 — `fftSetup` is now `FFTSetup?` optional; `guard let setup = fftSetup` used at call site)

**Location:** `Plugins/Services/AudioFFTProcessor.swift:40`

```swift
self.fftSetup = vDSP_create_fftsetup(n, FFTRadix(kFFTRadix2))!
```

**Risk:** If vDSP setup fails (memory pressure, invalid params), the app crashes on audio service init. No recovery path. Replace `!` with `guard let` + graceful degradation to simulated mode.

---

### BUG-4 — Unstructured Observer Tasks in NotchObserverSetup Have No Cancellation

**Status:** ✅ Fixed (Phase 15.5 — `deinit { observerTasks.forEach { $0.cancel() } }` in `NotchObserverSetup.swift`)

**Location:** `Core/NotchObserverSetup.swift:46–72`

Two `Task { @MainActor in }` blocks launched in `setupDetectorObserver()` are never stored or cancelled. If `NotchObserverManager` deallocates, these tasks continue running and invoking the callback. The `[weak self]` capture prevents crashes but leaves zombie observers polling indefinitely.

**Fix:** Store task references as properties, cancel in `deinit`.

---

### BUG-5 — Recursive Observation Accumulation in startEarsTracking

**Status:** ✅ Fixed (Phase 15.5 — `startEarsTracking()` now cancels `earsTrackingTask` before re-subscribing via structured Task)

**Location:** `ViewModel/NotchViewModel+Observers.swift:57–64`

`startEarsTracking()` sets up a new `withObservationTracking` block each time it's called, then calls itself recursively from the `onChange` handler. Every ears state change creates a new observation without cleaning up the previous one. Over time with frequent music state changes, observations accumulate.

**Fix:** Guard with `earsTrackingActive` flag or store the tracking handle for cleanup before re-subscribing.

---

### BUG-6 — Silent try? Swallows Task Cancellation Signal

**Status:** ✅ Fixed (Phase 15.5 — `KeyboardShortcutCoordinator.swift` replaced `try?` with `do { try await ... } catch { return }`)

**Locations:**

- `Core/KeyboardShortcutCoordinator.swift:100`: `try? await Task.sleep(for: .seconds(3))`
- `ViewModel/NotchViewModel+OpenClose.swift:91`: `try? await Task.sleep(for: .milliseconds(300))`

`try?` on `Task.sleep()` silently swallows `CancellationError`. Fix: `do { try await Task.sleep(...) } catch { return }`. Note: a redundant `guard !Task.isCancelled` after the `catch` block is unreachable on the cancellation path (CancellationError already exits in the catch) — effectively dead code but harmless.

---

### BUG-7 — @unchecked Sendable on AudioFFTProcessor Without Synchronization

**Status:** ✅ Fixed (Phase 15.4 — `@MainActor` added to `AudioFFTProcessor`; `@unchecked Sendable` removed)

**Location:** `Plugins/Services/AudioFFTProcessor.swift:14`

```swift
final class AudioFFTProcessor: @unchecked Sendable {
```

Comment (line 8) says "call exclusively from a single serial context" — but this is trust-based. The class holds mutable arrays (`sampleAccumulator`, `previousBands`, `peakBands`) with no lock/actor protection. If ever called from two contexts simultaneously (e.g., SCK audio callback + MainActor), data races corrupt FFT output silently. Add `@MainActor` or explicit `NSLock` to match documented intent.

---

### Mock/Fake Data Inventory

The following non-test mocks/simulated data exist in production code paths:

| File | Type | Impact |
|------|------|--------|
| `MockAudioCaptureService.swift` | Fallback service — energy-based random data | Used when screen recording permission denied. Correct as fallback. |
| `ScreenCaptureKitAudioService.swift` `DummyVideoOutput` | Dummy video output to satisfy SCK API | Intentional — SCK requires video stream even for audio-only. |
| `AmbientVisualizerMode.simulated` | Generative `sin()`/`cos()` animation | Intentional — `.simulated` mode is a feature, not a bug. Default mode. |
| `MockNotchSettings.swift` | Full settings mock | Used in SwiftUI `#Preview` blocks only. ✅ Correct scope. |
| `DefaultsKeys.swift:92` | `ambientVisualizerMode` defaults to `.simulated` | BUG-1 is fixed — consider defaulting to `.realAudio` now. Requires screen recording permission prompt on first use. |

---

## Architecture Audit (2026-03-23)

Full audit: 333 Swift files, ~36K LOC, 3 parallel analysis agents.

### DDD Compliance Assessment

**Overall: ~70% toward clean DDD.** Strong bounded contexts, clean domain layer, solid event bus decoupling. Weaknesses concentrated in presentation layer (god object) and plugin registration mechanism.

| Layer | Score | Evidence |
|-------|-------|---------|
| **Domain** | ✅ 9/10 | `Core/` domain files have zero SwiftUI/AppKit imports. `NotchStateMachine` is pure, testable, framework-free. `NotchPhase`, `SneakPeekTypes`, `NotchSettingsSubProtocols`, `MockNotchSettings` all compile on Foundation-only. |
| **Application** | ⚠️ 7/10 | `PluginManager`, `PluginContext`, coordinators are clean. One violation: `DefaultsKeys.swift:164` accesses concrete `MusicManager.isNowPlayingDeprecatedStatic` from application layer. |
| **Infrastructure** | ✅ 8/10 | Services are protocol-backed. `ServiceContainer` is the DI root. Main weakness: mixes container + factory responsibilities (constructs 40+ services inline). |
| **Presentation** | ⚠️ 6.5/10 | `NotchContentRouter` is clean. `NotchViewModel` is a god object (704 lines, 8 responsibilities). `PluginManager+ViewHelpers` has OCP-violating switch. 3 view files access concrete `MusicManager`. |

### Architecture Strengths

- **Plugin isolation via event bus** — Plugins cannot import each other. All inter-plugin communication flows through `PluginEventBus`. Adding a plugin never touches existing plugins.
- **Domain purity** — `NotchStateMachine` is a pure function of inputs. No UI framework imports in domain layer. Independently testable.
- **Protocol-backed services** — Every service has a protocol. `MockNotchSettings` enables `#Preview` without real services. The DI chain from `AppObjectGraph` → `ServiceContainer` → `PluginContext` is clean.
- **Bounded contexts per plugin** — `ShelfPlugin/`, `MusicPlugin/`, etc. each own their models, views, and services. No namespace pollution.
- **ISP sub-protocols exist** — `MediaServiceProvider`, `SystemServiceProvider`, `StorageServiceProvider`, etc. are defined. Not enforced at compile time yet, but the vocabulary is there.

### Path from 70% to 90%+ DDD

Ordered by effort/impact ratio:

| Priority | Change | Effort | Impact |
|----------|--------|--------|--------|
| **P0** | Fix BUG-2 (width race) | Low | UX stability |
| **P1** | Replace `MusicManager.isNowPlayingDeprecatedStatic` calls with a protocol (4 files) | Low | Layer purity |
| **P1** | Fix `NotificationsPlugin` concrete `ServiceContainer` cast | Low | DIP compliance |
| **P2** | Type-erase `PluginManager+ViewHelpers` switch statements | Medium | OCP compliance; required for Phase 9 |
| **P2** | Extract `NotchPhaseCoordinator` from `NotchViewModel` | Medium | SRP, testability |
| **P3** | Enforce ISP service contracts on `PluginContext` generics | High | Compile-time safety for Phase 9 |
| **P3** | Separate plugin factory from `AppObjectGraph` | High | Enables Phase 9 dynamic loading |

### Plugin System Score: 7.5/10

| Dimension | Score | Note |
|-----------|-------|------|
| Plugin Isolation | 8.5/10 | Event bus prevents coupling; discovery is hardcoded |
| DI Completeness | 7.5/10 | PluginContext solid; service access trust-based not enforced |
| Presentation Clarity | 6.5/10 | ContentRouter excellent; NotchViewModel bloated |
| Service Architecture | 8/10 | ISP protocols good; ServiceContainer mixes factory concerns |
| Lifecycle Management | 7/10 | Clean activate/deactivate; activation ordering not declarative |
| Testability | 7/10 | StateMachine testable; integration tests hard via god objects |
| Extensibility | 6.5/10 | ViewHelpers switch blocks true plug-and-play |
| Code Quality | 7/10 | 300-line limit met; @Observable/@MainActor consistent; concurrency edge cases remain |

---

## Phase 15 — Architecture Hardening (Completed)

**Goal:** Close the gap from ~70% to 90%+ DDD compliance. Fix open bugs. Enforce layer boundaries. Prepare plugin infrastructure for Phase 9 third-party distribution.

**Constraint:** All changes must keep build green and tests passing. Work in isolation-safe commits.

### 15.1 — Fix BUG-2: Notch Width Race

**Priority:** P0 | **Effort:** Low | **Files:** `KeyboardShortcutCoordinator.swift`, `NotchViewModel+OpenClose.swift`

Gate `effectiveClosedNotchSize` ear-width additions on `phase == .closed`. Width should not mutate while the notch is open or transitioning. See BUG-2 above for full root cause.

### 15.2 — Abstract MusicManager.isNowPlayingDeprecatedStatic

**Priority:** P1 | **Effort:** Low | **Files:** 4 violation sites + new protocol

Create `MediaControllerCapabilityProtocol` or add `isNowPlayingDeprecated: Bool` to an existing settings sub-protocol. Inject via `NotchSettings` or `NotchServiceProvider`. Replace 4 direct calls.

### 15.3 — Fix NotificationsPlugin ServiceContainer Cast

**Priority:** P1 | **Effort:** Low | **Files:** `NotificationsPlugin.swift:51`

Add the required service property to the appropriate `ServiceProvider` sub-protocol. Remove the concrete downcast.

### 15.4 — Fix AudioFFTProcessor Crash Risk + Data Race

**Priority:** P1 | **Effort:** Low | **Files:** `AudioFFTProcessor.swift`

- Replace force-unwrap on `vDSP_create_fftsetup` with `guard let` + graceful fallback
- Add `@MainActor` to enforce single-threaded access (matches comment on line 8)
- Remove `@unchecked Sendable`

### 15.5 — Fix Unstructured Observer Tasks

**Priority:** P1 | **Effort:** Low | **Files:** `NotchObserverSetup.swift`, `NotchViewModel+Observers.swift`

- Store Task references in `NotchObserverManager`, cancel in `deinit`
- Fix recursive `startEarsTracking()` with active-flag guard
- Add `deinit` to `NotchViewModel` cancelling `hideOnClosedDebounceTask`, `earsDebounceTask`, `closeWatchdogTask`, `postCloseHoverTask`

### 15.6 — Type-Erase PluginManager+ViewHelpers Switch

**Priority:** P2 | **Effort:** Medium | **Files:** `Plugins/UI/PluginManager+ViewHelpers.swift`, `AnyNotchPlugin`

Extend `AnyNotchPlugin` with type-erased `closedNotchContentView()`, `expandedPanelContentView()`, `settingsContentView()` → `AnyView`. Remove the `switch id { case PluginID.music: ... }` pattern. Required before Phase 9 (external plugins cannot be listed in a switch).

### 15.7 — Extract NotchPhaseCoordinator from NotchViewModel

**Priority:** P2 | **Effort:** Medium | **Files:** `NotchViewModel+OpenClose.swift` → `Core/NotchPhaseCoordinator.swift`

Extract open/close state machine + watchdog tasks into a dedicated `@MainActor @Observable` class. `NotchViewModel` delegates to it. Reduces NotchViewModel responsibility count from 8 to 7, makes open/close independently testable.

### Phase 15 Implementation Order

| Priority | Task | Effort | Unblocks |
|----------|------|--------|---------|
| **P0** | 15.1 Fix BUG-2 | Low | UX stability |
| **P1** | 15.2 Abstract MusicManager static | Low | Layer purity |
| **P1** | 15.3 Fix NotificationsPlugin cast | Low | DIP compliance |
| **P1** | 15.4 AudioFFTProcessor safety | Low | Crash prevention |
| **P1** | 15.5 Fix observer tasks | Low | Memory leak prevention |
| **P2** | 15.6 Type-erase ViewHelpers switch | Medium | Phase 9 |
| **P2** | 15.7 Extract NotchPhaseCoordinator | Medium | NotchViewModel SRP |

### Phase 15 Success Metrics

- [x] BUG-2 never reproduces (notch width stable during keyboard-triggered open)
- [x] Zero presentation/application layer files import concrete `MusicManager`
- [x] `NotificationsPlugin` uses protocol, not concrete cast
- [x] `AudioFFTProcessor` has no force unwraps, has `@MainActor`
- [x] All unstructured `Task` refs stored and cancellable
- [x] `PluginManager+ViewHelpers` has no `switch id { case PluginID... }` pattern
- [x] Adding a new plugin requires zero changes to `PluginManager+ViewHelpers`

---

## Phase 13 — Notch Video Player (Long-Term)

**Goal:** Small PiP-style video player extending the notch for ambient video viewing. YouTube playing in your notch while you code.

**Status:** Concept — needs research spike before committing to architecture.

**Design Principle:** The notch becomes a viewport. Not a replacement for full-screen video — an ambient companion for content you're half-watching. Lectures, tutorials, live streams, music videos.

### Architecture (Proposed)

```
Video Source
├── AVPlayer (local files, direct URLs, HLS/DASH streams)
├── yt-dlp extraction (YouTube → stream URL → AVPlayer)
└── ScreenCaptureKit window capture (any app, future)
        │
        ▼
VideoPlayerPlugin
├── VideoSourceService (protocol)
├── VideoPlayerState (@Observable)
└── VideoPlayerRenderer (AVPlayerLayer)
        │
        ▼
closedNotchContent() → extended notch video viewport
```

### 13.1 — Video Source Service

**Status:** Concept | **Priority:** Research spike

```swift
protocol VideoSourceServiceProtocol {
    func loadURL(_ url: URL) async throws -> VideoSource
    func loadFile(_ path: URL) async throws -> VideoSource
}

enum VideoSource {
    case avPlayer(AVPlayer)          // Direct playback
    case streamURL(URL, format: StreamFormat)  // HLS/DASH
}
```

**Source strategies (ordered by feasibility):**

| Source | Feasibility | Approach | DRM Risk |
|--------|------------|----------|----------|
| Local files (.mp4, .mov) | Easy | `AVPlayer(url:)` | None |
| Direct video URLs | Easy | `AVPlayer(url:)` | None |
| YouTube | Medium | `yt-dlp` extracts stream URL → `AVPlayer` | Low (yt-dlp handles) |
| Browser tab video | Hard | Browser extension `captureStream()` + WebRTC → native | High (DRM blocks) |
| Any window capture | Hard | `ScreenCaptureKit` window filter | Medium |

**MVP strategy:** Start with AVPlayer (local + direct URL) + yt-dlp YouTube extraction. Browser integration deferred.

### 13.2 — Extended Notch Video Viewport

**Status:** Concept | **Priority:** P1 (after 13.1 research)

**Dimensions:**

- Notch width: ~200px (varies by MacBook model)
- 16:9 aspect at 200px wide = ~112px tall
- 4:3 aspect at 200px wide = ~150px tall
- Configurable: fit (letterbox) vs fill (crop)

**Layout:**

```
┌──────────────────────┐
│   ▓▓▓▓ NOTCH ▓▓▓▓   │  ← Camera + notch hardware
├──────────────────────┤
│                      │
│   ┌──────────────┐   │  ← Video viewport (16:9)
│   │  ▶ VIDEO     │   │     AVPlayerLayer renders here
│   └──────────────┘   │
│                      │
└──────────────────────┘
```

**Renderer:** `AVPlayerLayer` wrapped in `NSViewRepresentable`. Not SwiftUI `VideoPlayer` (too heavy for notch constraints).

### 13.3 — Playback Controls

**Status:** Concept | **Priority:** P1

**Closed notch (hover-to-reveal):**

- Play/pause (center)
- Volume (left, mini slider)
- Close (right, X button)
- Progress bar (bottom edge, thin)
- Click video → expand notch to show full controls

**Expanded panel:**

- Full playback controls (play, pause, seek, volume, speed)
- URL input field (paste YouTube/video URL)
- File picker button (local files)
- Video queue / history
- Picture-in-Picture breakout button (detach to native macOS PiP)
- Aspect ratio toggle (fit/fill)

### 13.4 — YouTube Integration via yt-dlp

**Status:** Concept | **Priority:** P2

```swift
struct YTDLPExtractor {
    func extractStreamURL(from youtubeURL: URL) async throws -> URL
}
```

- Shell out to `yt-dlp --get-url --format "best[height<=720]"` (720p max for notch-sized viewport)
- Requires `yt-dlp` installed (`brew install yt-dlp`)
- Cache extracted URLs (they expire, typically ~6h)
- Graceful error: "Install yt-dlp for YouTube support" in settings
- Future: bundle `yt-dlp` binary or use Swift port

### 13.5 — Browser Extension Enhancement (Future)

**Status:** Deferred — research needed

Extend the existing browser extension to support video frame streaming:

- Detect `<video>` elements on active tab
- Send video metadata (title, duration, current time) — **already exists**
- New: "Play in Notch" button overlay on detected videos
- New: extract video source URL when not DRM-protected → send to native `AVPlayer`
- DRM content (Netflix, Disney+): not supported, show clear message

### 13.6 — Video Player Settings

| Setting | Type | Default |
|---------|------|---------|
| Video player enabled | Toggle | On |
| Default aspect ratio | Picker | Fit (letterbox) |
| Auto-pause on expand | Toggle | On |
| Playback speed | Picker | 1.0x |
| Volume | Slider | System |
| yt-dlp path | Text field | Auto-detect |
| Max resolution | Picker | 720p |

**API endpoints (self-registered):**

```
POST /api/v1/video/load          → { url: "https://..." }
POST /api/v1/video/play-pause
POST /api/v1/video/seek          → { position: 0.5 }
GET  /api/v1/video/state         → { url, isPlaying, position, duration }
POST /api/v1/video/close
```

### 13.7 — Research Spike Checklist

Before committing to implementation, validate:

- [ ] `ScreenCaptureKit` audio-only capture works reliably (Phase 12 prerequisite validates this)
- [ ] `AVPlayerLayer` renders correctly in notch window (window level, compositing)
- [ ] `yt-dlp` stream URL extraction is fast enough (<2s) and reliable
- [ ] Video playback CPU/GPU impact at 720p in 200px viewport
- [ ] Memory footprint of AVPlayer with HLS stream
- [ ] macOS PiP API (`AVPictureInPictureController`) integration from custom window
- [ ] Browser extension `captureStream()` DRM limitations on major sites

---

## Phase 12/13 Implementation Order

| Priority | Task | Depends On | Impact |
|----------|------|------------|--------|
| **P0** | 12.1 Audio Capture Service | — | Foundation for all visualizer work |
| **P0** | 12.2 FFT Processor | 12.1 | Turns raw audio into usable data |
| **P0** | 12.4 Extended Notch Display | — | Rendering surface for visualizer |
| **P1** | 12.3 Visualization Modes (Spectrum Bars) | 12.1, 12.2, 12.4 | MVP visualizer |
| **P1** | 12.6 Visualizer Settings | 12.3 | User customization |
| **P2** | 12.3 Visualization Modes (Waveform, Gradient, Radial) | 12.3 | Additional modes |
| **P2** | 12.5 Album Art Color Extraction | — | Visual polish |
| **P3** | 13.1 Video Source Service (research spike) | — | Validate feasibility |
| **P3** | 13.2 Video Viewport | 13.1 | Core video display |
| **P3** | 13.3 Playback Controls | 13.2 | Basic usability |
| **P3** | 13.4 YouTube/yt-dlp Integration | 13.2 | Key use case |
| **Future** | 13.5 Browser Extension Enhancement | 13.2 | DRM research needed |

---

## Vision: The Notch as Ambient Display Platform

```
┌─────────────────────────────────────────────────────────────────┐
│                    External World                                │
│  curl / Raycast / Browser Ext / Python / AI Agents / Shortcuts  │
└──────────────────────────┬──────────────────────────────────────┘
                           │ REST + WebSocket (localhost:19384)
┌──────────────────────────▼──────────────────────────────────────┐
│                    LocalAPIServer                                │
│  Routes → PluginManager    WebSocket ↔ PluginEventBus           │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                    Plugin Layer                                   │
│  ┌──────────┐ ┌──────────────┐ ┌────────────┐ ┌─────────────┐  │
│  ┌──────────┐ ┌──────────────┐ ┌────────────┐ ┌─────────────┐  │
│  │ Music    │ │ Teleprompter │ │ Display    │ │ Calendar    │  │
│  │ Battery  │ │ Pomodoro     │ │ Surface    │ │ Shelf       │  │
│  │ Webcam   │ │ HabitTracker │ │ (generic)  │ │ Clipboard   │  │
│  │Visualizer│ │ VideoPlayer  │ │            │ │             │  │
│  └──────────┘ └──────────────┘ └────────────┘ └─────────────┘  │
│        Built-in              API-powered         Built-in        │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                    Service Layer                                  │
│  ServiceContainer → Protocol-based services → System APIs        │
└─────────────────────────────────────────────────────────────────┘
```

**The key insight:** The notch is the most camera-adjacent, always-visible, least-intrusive display surface on a MacBook. Making it API-driven turns it into a **personal HUD** for any local tool.

---

## Success Metrics

| Phase | Done When |
|-------|-----------|
| 4 | Open/close feels smooth and interruptible. No "stuck" phase transitions. Content fades in progressively. |
| 4a | ✅ **Done.** Zero arch violations. All 9 items resolved. Build green + 28 tests pass. CLAUDE.md updated. |
| 5 | ✅ **Done.** `curl localhost:19384/api/v1/notch/state` returns valid JSON. All REST endpoints shipped (notch, plugins, music). Auth + rate limiting enforced. WebSocket streams enriched events. `notchctl` works. |
| 6 | ✅ **Done.** Teleprompter scrolls API-fed text. DisplaySurface renders arbitrary content from `curl`. |
| 6b | ✅ **Done.** 3-tier AI architecture. Domain protocol with deterministic fallback. No singleton access. Prompt engineering encapsulated. *(Phase 11: Foundation Models becomes primary, oMLX becomes advanced local.)* |
| 7 | ✅ **Done.** App Intents in Shortcuts. URL scheme routes work (including toggle). |
| 9 | External plugin loads from `~/Library/Application Support/machNotch/Plugins/`. |
| 10 | Expanded panel uses full 740px with two-column layout (editor + controls). Script library persists named scripts. Countdown timer works. Keyboard shortcuts for hands-free control. Closed display shows 2–3 lines with karaoke fade, progress bar, elapsed/remaining time. Voice-driven scrolling as optional Flow Mode. Screen sharing safety via `sharingType = .none`. Detachable floating window for external displays. Creator-daily-driver quality. |
| 11 | `FoundationModelsProvider` is sole default provider on macOS 26+. AI features work with zero external dependencies. oMLX available as opt-in Advanced local option only. Streaming AI responses in teleprompter UI. Structured generation via `@Generable`. On macOS <26: AI features cleanly absent unless oMLX is explicitly configured. |
| 12 | Real audio-reactive visualizer responds to actual system audio. Extended notch height configurable. Album art color extraction for theming. Idle: 3% CPU (✅). Active: ~11% CPU (⚠️ over target — SCK framework overhead; long-term fix: system audio tap API). Permission denial degrades gracefully to simulated animation. |
| 13 | Video plays in notch viewport via AVPlayer. YouTube URLs load via yt-dlp. Hover reveals mini controls. Expanded panel has full controls + URL input. <5% CPU at 720p. Browser extension video integration validated or descoped. |
| 15 | BUG-2 never reproduces. Zero concrete `MusicManager` refs outside infra layer. `AudioFFTProcessor` crash-free with `@MainActor`. All observer Tasks stored + cancellable. `PluginManager+ViewHelpers` has no plugin switch statements. DDD compliance at 90%+. |

---

## Phase 16 — New Plugins

All as `NotchPlugin` conformances. No `PluginManager` modifications. Each plugin: new folder at `Plugins/BuiltIn/<Name>Plugin/`, register in `AppObjectGraph`, add `PluginID` constant. See `docs/Guide.md` for the full plugin authoring guide.

---

### Plugin 1: SystemStats

**Inspiration:** OneMenu, Atoll | **Reference:** [exelban/stats](https://github.com/exelban/stats) (GPL v3) | **License note:** Independent reimplementation — zero exelban/stats code. All system metrics via standard public APIs (`host_statistics64`, `FileManager`, `getifaddrs`, `IOAccelerator`).

**Goal:** Show CPU/GPU/RAM/disk/network usage as circular ring indicators in the notch. Most visually impactful addition — makes the notch a live system monitor.

**View slots:**

- `closedNotchContent` — Row of 3–5 compact ring indicators (CPU %, RAM %, disk %). Positioned right side. Yields to music plugin.
- `expandedPanelContent` — Full panel: larger rings + numeric values + sparkline history (last 60s).
- `settingsContent` — Toggle which metrics to show, refresh interval (1s/3s/5s), ring color scheme.

**Services needed:**

- New `SystemStatsServiceProtocol` + `SystemStatsService` in `Plugins/Services/`
- CPU: `host_statistics64` via `mach/mach.h` — no special permissions
- RAM: `host_statistics64(HOST_VM_INFO64)` — no special permissions
- Disk: `FileManager.default.attributesOfFileSystem(forPath: "/")` — no special permissions
- Network: `getifaddrs` or `SystemConfiguration` — no special permissions
- GPU: `IOServiceGetMatchingServices` with `IOAccelerator` — no special permissions

**Architecture decisions:**

- Stats polled on a background `Task` at configurable interval, published via `@Published` on service
- No SMC required for basic CPU/RAM/disk/network — SMC only needed for temperature (defer to later)
- Ring views are pure `Shape`-based SwiftUI — no Metal, no SCK overhead
- `displayRequest` = `.background` priority — never interrupts music or other content

**Permissions:** None required.

---

### Plugin 2: PreventSleep

**Inspiration:** OneMenu

**Goal:** Toggle that prevents macOS from sleeping while active. Single-purpose, zero complexity. Good first plugin to validate the renamed scaffold.

**View slots:**

- `closedNotchContent` — Small moon icon with filled/unfilled state. Far-right position.
- `menuBarView` — "Prevent Sleep: ON/OFF" toggle item.
- `settingsContent` — Toggle + optional auto-disable timer (30min/1h/2h/never).

**Services needed:**

- No new service — IOKit called directly in plugin
- `IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep, kIOPMAssertionLevelOn, "mach.notch PreventSleep" as CFString, &assertionID)`
- `IOPMAssertionRelease(assertionID)` on deactivate or toggle-off

**Architecture decisions:**

- `assertionID: IOPMAssertionID` stored as instance var — released in `deactivate()`
- Auto-timer cancels assertion via `Task.sleep` + structured cancellation
- `displayRequest` = nil — closed icon is enough, never requests sneak peek

**Permissions:** None required.

---

### Plugin 3: ExternalBrightness

**Inspiration:** OneMenu | **Reference:** [MonitorControl](https://github.com/MonitorControl/MonitorControl) (GPL v3) | **License note:** Independent reimplementation — zero MonitorControl code. DDC via public IOKit APIs (`IOFramebufferConnectControl`, `IOAVServiceWriteI2C`); `CoreDisplay` as fallback.

**Goal:** Control external monitor brightness via DDC (Display Data Channel) directly from the notch. No third-party app required.

**View slots:**

- `closedNotchContent` — Sun icon + current brightness % when external monitor detected.
- `expandedPanelContent` — Slider per connected external monitor. Monitor name label.
- `settingsContent` — Toggle DDC vs CoreDisplay fallback, step size.

**Services needed:**

- New `ExternalBrightnessServiceProtocol` + `ExternalBrightnessService`
- DDC via `IOFramebufferConnectControl` / `IOAVServiceWriteI2C` (same approach as MonitorControl)
- Or: `CoreDisplay` private framework (`DisplayServicesSetBrightness`) — simpler but private API
- Recommend: DDC first (public IOKit), `CoreDisplay` as fallback
- Monitor enumeration: `CGGetActiveDisplayList` + `IOServicePortFromCGDisplayID`

**Architecture decisions:**

- DDC I2C writes go through XPC helper (requires elevated IOKit access) — reuse `MachNotchXPCHelper`
- Add `setExternalBrightness(_:forDisplay:)` to `MachNotchXPCHelperProtocol`
- No external monitor = plugin shows nothing (empty closed content)
- `displayRequest` = nil normally; `.normal` priority when slider is actively dragged

**Permissions:** None required for DDC. Screen Recording NOT needed.

---

### Plugin 4: ColorPicker

**Inspiration:** Atoll

**Goal:** Pick any color from the screen, copy hex/RGB to clipboard, maintain a recent color history.

**View slots:**

- `closedNotchContent` — Small color swatch showing last picked color. Tap to re-copy.
- `expandedPanelContent` — Color history grid (last 12 colors), each tappable to copy. "Pick New" button.
- `settingsContent` — Copy format (hex, RGB, HSL, Swift Color), history size (12/24/48).

**Services needed:**

- No new service — `NSColorSampler` called directly in plugin
- History persisted via `PluginSettings` (array of hex strings)
- `NSColorSampler().show { color in ... }` — blocks until user clicks or cancels

**Architecture decisions:**

- `NSColorSampler` is synchronous/callback-based — wrap in `withCheckedContinuation`
- Picking triggers a `SneakPeekRequestedEvent` to show the result after pick
- Color history stored as `[String]` (hex) in `PluginSettings` — no external storage
- `displayRequest` = `.normal` after successful pick (shows the new color briefly)

**Permissions:** None required — `NSColorSampler` uses system picker with no screen recording entitlement needed.

---

### Plugin 5: FocusMode

**Inspiration:** Atoll live activities

**Goal:** Show the currently active Focus mode (Work, Personal, Sleep, Do Not Disturb) in the closed/expanded notch. Passive indicator — no controls.

**View slots:**

- `closedNotchContent` — Focus icon + short name (e.g., "Work") when a Focus is active. Hidden when no Focus active.
- `expandedPanelContent` — Focus name + description + scheduled end time if available.
- `settingsContent` — Toggle which Focus modes to show, icon style.

**Services needed:**

- New `FocusModeServiceProtocol` + `FocusModeService`
- `FocusFilterAppContext` is not usable here — use `NEFilterManager` or notification center
- Correct approach: `NSNotificationCenter` + `CFNotificationCenter` for Focus change notifications
- Or: `CNContact`-adjacent private API — avoid
- Best: `UserNotifications.UNUserNotificationCenter` + `currentNotificationSettings` polling — simple but polling
- **Recommended:** `NSDistributedNotificationCenter` for `com.apple.springboard.focus-changed` — private but stable, used by many apps

**Architecture decisions:**

- Poll every 30s as fallback if distributed notification unavailable
- Focus name derived from `NEFilterManager.shared().localizedDescription` — unreliable
- Better: `com.apple.donotdisturb.state.current` UserDefaults key (private, stable)
- `displayRequest` = `.normal` only when Focus just changed (show briefly); `.background` otherwise

**Permissions:** None required for passive observation.

---

### Plugin 6: Downloads

**Inspiration:** Atoll

**Goal:** Show active file downloads in the notch — progress bars for in-flight downloads from browsers and system.

**View slots:**

- `closedNotchContent` — Download progress ring + filename truncated. Hidden when no active downloads.
- `expandedPanelContent` — List of active downloads, each with progress bar + filename + speed + ETA.
- `settingsContent` — Watch folder path (default `~/Downloads`), browser extension toggle.

**Services needed:**

- New `DownloadsServiceProtocol` + `DownloadsService`
- FSEvents via `DispatchSource.makeFileSystemObjectSource` on `~/Downloads`
- Detect in-progress downloads: `.download` partial files (`.crdownload`, `.part`, `.tmp`)
- Progress: compare file size over time (poll every 500ms for active `.crdownload` files)
- Speed: delta bytes / delta time
- ETA: remaining bytes / current speed

**Architecture decisions:**

- `FSEventStream` watched on background actor — no main thread FS I/O
- Only files modified in last 60s considered "active" — older ones are complete
- Browser-specific patterns: `.crdownload` (Chrome/Brave), `.part` (Firefox), `.download` (Safari)
- `displayRequest` = `.high` when download active (user wants to see progress); nil when idle

**Permissions:** None required — `~/Downloads` is user-accessible without entitlements.

---

### Plugin 7: MenuBar (Menu Bar Absorber)

**Inspiration:** Ice (GPL v3) | **License note:** Independent reimplementation — zero Ice code. Same underlying macOS mechanisms, original implementation.

**Goal:** Absorb configured menu bar icons into the notch. User-selected icons disappear from the menu bar and reappear as tappable items inside the expanded notch panel. Clears menu bar clutter without quitting apps.

**View slots:**

- `closedNotchContent` — Hidden (absorber is invisible in closed state by design).
- `expandedPanelContent` — Horizontal row of absorbed icon images. Each is tappable — sends a synthetic click to the original NSStatusItem, opening its popover/menu as normal.
- `settingsContent` — List of detected menu bar apps. Toggle per-app to absorb. Drag to reorder.

**Services needed:**

- New `MenuBarServiceProtocol` + `MenuBarService` in `Plugins/Services/`
- Item enumeration: `CGWindowListCopyWindowInfo(CGWindowListOption.optionOnScreenOnly, kCGNullWindowID)` filtered to `kCGWindowLayer == 25` (menu bar layer)
- Icon capture: `CGWindowListCreateImage` per item window — renders the icon as-is
- Hiding mechanism: Place a sentinel `NSStatusItem` (zero-width, always rightmost) as a section divider. Items configured for absorption are moved right of the sentinel via `CGSSetWindowAlpha(_:_:_:)` + `CGSSetWindowLevel` to render them invisible in place — no position shuffling needed.
- Click passthrough: `AXUIElementPerformAction` on the item's `AXPress` action — triggers the original app's menu/popover without screen recording permission.

**Architecture decisions:**

- `CGSSpace.swift` already in `private/` — reuse connection handle (`_CGSDefaultConnection()`)
- Hiding is alpha-based (invisible but present), not positional — avoids fighting macOS's auto-layout of the status bar
- Icon images cached on a background actor; refreshed when `CGWindowListCopyWindowInfo` detects a change
- Absorbed items persisted as bundle IDs in `PluginSettings` — survives relaunches
- On `deactivate()`: restore alpha to 1.0 for all absorbed items — no orphaned invisible icons
- `displayRequest` = nil — never requests sneak peek proactively

**Permissions:** `NSAccessibilityUsageDescription` — required for `AXUIElementPerformAction` click passthrough.

**Anti-pattern (what Ice does that we don't):** Ice uses control items as section dividers and moves items positionally. We avoid positional moves — they require fighting macOS's status bar layout engine and are the source of most of Ice's 1671-line complexity. Alpha-hiding is simpler and sufficient for our use case.

---

### Plugin 8: Battery

**Inspiration:** Al Dente, native macOS battery menu

**Goal:** Replace the third-party battery menu bar app. Show charge %, source, and energy mode in the notch. Includes charge limit toggle (keep battery at 80% to preserve long-term health).

**View slots:**

- `closedNotchContent` — Battery icon + % when not plugged in, or charging indicator when plugged. Amber pulse below 20%.
- `expandedPanelContent` — Charge %, power source (battery / adapter + slow/fast/MagSafe label), energy mode picker (Automatic / Low Power / High Performance), charge limit toggle (80% cap).
- `settingsContent` — Low battery threshold for amber pulse, show/hide in closed notch.

**Services needed:**

- New `BatteryServiceProtocol` + `BatteryService`
- `IOPSCopyPowerSourcesInfo()` + `IOPSGetPowerSourceDescription()` — charge %, source, adapter wattage
- `IOPSNotificationCreateRunLoopSource` — event-driven updates, no polling
- Energy mode: `pmset -g` via `Process` to read; `pmset lowpowermode 1/0` via XPC helper to write (requires admin — use `AuthorizationExecuteWithPrivileges` in XPC helper)
- Charge limit (80% cap): `smckit` / `IOSMCFamily` private API — or `pmset` with `charge` key if available. Mark as v2 if SMC access is complex.

**Architecture decisions:**

- `IOPSNotification` on main RunLoop — SwiftUI-friendly, no polling
- Energy mode write goes through existing `MachNotchXPCHelper` — add `setEnergyMode(_:)` to XPC protocol
- Amber pulse via `PluginEventBus` publishing a `BatteryLowEvent` — other plugins can react
- `displayRequest` = `.background` normally; `.high` when battery drops below threshold

**Permissions:** None for reading. XPC helper handles energy mode writes.

---

### Plugin 9: DevActivity

**Inspiration:** cmux (GPL) | **License note:** Independent reimplementation — zero cmux code.

**Goal:** Show active Claude Code (and general tmux) session status in the notch. Replace the cmux menu bar icon. Surface "waiting for input" state as an ambient notch indicator — tap to jump to the relevant terminal session.

**View slots:**

- `closedNotchContent` — Subtle indicator dot + session count when any session is waiting for input. Hidden when all sessions idle.
- `expandedPanelContent` — List of active tmux sessions with their last output snippet. "Waiting for input" vs "Running" vs "Idle" states. Tap to bring Terminal/iTerm to front on that session.
- `settingsContent` — Socket path (default `$TMPDIR/tmux-*/default`), refresh interval, filter by session name prefix.

**Services needed:**

- New `DevActivityServiceProtocol` + `DevActivityService`
- tmux socket enumeration: `glob($TMPDIR/tmux-*/default)` — no tmux binary dependency
- Session list: `tmux -S <socket> list-sessions -F "#{session_name}:#{session_activity}"` via `Process`
- "Waiting for input" detection: check if the active pane's process is awaiting stdin — `tmux -S <socket> display-message -p "#{pane_current_command}"` → if `claude`, `node`, `python` etc. and no recent output, classify as waiting
- Claude Code specifically: parse `~/.claude/projects/` activity or use `tmux` pane title (Claude Code sets the pane title)
- Bring-to-front: `NSRunningApplication(processIdentifier:)?.activate()` + AppleScript to select the right tmux window

**Architecture decisions:**

- Poll every 10s via `Task` with structured cancellation — tmux has no push API
- `Process` calls on a background actor — no main thread blocking
- Session state diffed on each poll — only publish changes, not full refresh
- `displayRequest` = `.high` when a session transitions to "waiting for input" (brief sneak peek); `.background` otherwise
- Graceful degradation: if tmux not found or no socket, plugin shows nothing silently

**Permissions:** None required — tmux socket is user-accessible.

---

### Plugin 10: Brief

**Dependency:** `Packages/MachBriefKit` (shared Bazel-built package, also powers `Apps/machBrief/` macOS app — see `Plans/PRDs/machBrief-macOS.md`)

**Goal:** Show the current daily brief entry in the notch — word, fact, quote, mantra, or mood prompt depending on which sources the user has enabled. Same deterministic schedule as the machBrief app, same content at the same time.

**View slots:**

- `closedNotchContent` — Source icon + title snippet, right-aligned. Yields to music/active content.
- `expandedPanelContent` — Full entry card with source-appropriate layout: word card (phonetic + definition + example), quote card (quote + author), fact card, mood prompt with 5-option picker.
- `settingsContent` — Toggle which sources participate, link to machBrief macOS app for full settings.

**Services needed:**

- No new service — consumes `MachBriefKit.DailyScheduler`, `MachBriefKit.BriefStore`, and enabled `BriefSource` instances directly
- `MachBriefKit` added as Bazel dependency to `machNotch` target
- ObsidianSink wired if vault path is configured (shared config via `MachBriefKit.BriefStore`)

**Architecture decisions:**

- `MachBriefKit` is platform-agnostic Swift (no UIKit/AppKit) — links cleanly into macOS target
- `DailyScheduler` uses date-seeded PRNG — same slot content on iOS and macOS
- Mood check-in in expanded panel writes via `MoodCheckInSource` → triggers all configured sinks (Obsidian, HealthKit v2)
- `displayRequest` = `.background` — never interrupts active content

**Permissions:** None required (Obsidian file access via security-scoped bookmark set in machBrief macOS app, shared via `MachBriefKit`).

---

### Plugin 11: MoodJournal

**Category:** Same family as HabitTrackerPlugin (daily check-ins, personal data) — shares the emotional/behavioral tracking space.

**Goal:** Quick mood check-in from the notch. Works standalone (SwiftData). Recommended integration: Obsidian daily note append. Connects naturally to HabitTracker — mood is a daily signal like a habit completion.

**View slots:**

- `closedNotchContent` — Subtle emoji or color dot showing today's last mood. Hidden until first check-in of the day.
- `expandedPanelContent` — Two states:
  - **Check-in state** (default if no entry today): "How are you feeling?" + 5 pill buttons: Awesome · Good · Okay · Bad · Terrible. Optional one-line note field. Confirm tap logs and transitions to history state.
  - **History state** (after check-in): Today's mood + note. Scroll to see last 7 days as a mini timeline. Edit button to amend today's entry.
- `settingsContent` — Daily reminder time (optional notification), Obsidian vault path picker, markdown template editor, toggle show in closed notch.

**Services needed:**

- New `MoodServiceProtocol` + `MoodService` in `Plugins/Services/`
- Persistence: JSON file in app support dir (same pattern as `HabitStore`) — no SwiftData dependency
- Obsidian write: `FileManager` append to `<vault>/Daily/YYYY-MM-DD.md` via security-scoped bookmark
- Optional reminder: `UNUserNotificationCenter` scheduled notification at user-set time

**Data model:**

```swift
struct MoodEntry: Identifiable, Codable {
    let id: UUID
    let date: Date          // normalized to start of day
    let mood: MoodLevel
    let note: String?
    let loggedAt: Date
}

enum MoodLevel: Int, Codable, CaseIterable {
    case awesome = 5
    case good    = 4
    case okay    = 3
    case bad     = 2
    case terrible = 1

    var label: String { /* "Awesome", "Good", ... */ }
    var emoji: String { /* "😄", "🙂", "😐", "😔", "😞" */ }
}
```

**Obsidian output (appended to daily note):**

```markdown
## Mood — 18:32
Feeling: Good 🙂
Note: good focus session, finished the PRD planning
```

**Architecture decisions:**

- `MoodStore` mirrors `HabitStore` pattern — JSON persistence, `@Observable`, background save
- Obsidian write is fire-and-forget on a background task — failure logged silently, never blocks UI
- Security-scoped bookmark stored in `PluginSettings` — persists across relaunches without re-prompting
- `displayRequest` = `.normal` briefly after check-in (sneak peek to confirm); `.background` rest of day
- Connection to HabitTracker: `MoodJournalPlugin` publishes `MoodCheckedInEvent` on `PluginEventBus` — HabitTracker (or any future plugin) can react

**Permissions:** `UNUserNotificationCenter` authorization (optional, only if reminder enabled). File access via security-scoped bookmark (no special entitlement beyond `com.apple.security.files.user-selected.read-write`).

---

### ✅ HabitTracker (Shipped)

**Location:** `Plugins/BuiltIn/HabitTrackerPlugin/` — 6 files, registered in `PluginRegistry`.
**Status:** Fully working. Models, store (JSON persistence), closed view (dot indicators), expanded view (habit rows with toggle), settings view (add/edit/delete habits, color/symbol picker).
**Remaining:** No known gaps. Obsidian export and MoodJournal `MoodCheckedInEvent` integration are natural v2 additions.

---

## mach.window — App Spec

**Location:** `Apps/machWindow/` | **Bundle ID:** `com.larsboes.mach.window` | **License:** MIT (target — independent implementation, no GPL code)

### Why a separate app, not a plugin

Window management requires persistent system-level presence independent of the notch:

- Must intercept keyboard shortcuts globally even when machNotch is not focused
- Window snapping requires `NSAccessibility` — a separate process is cleaner and safer
- Hover peek requires screen capture of window thumbnails — separate process isolation
- Users may want window management without the notch app running

### MVP Scope (v0.1)

1. **Window snap zones** — drag a window near screen edges/corners → snap to halves/quarters
2. **Keyboard shortcuts** — customizable hotkeys for snap positions (left half, right half, maximize, restore)
3. **Hover peek** — hover over Dock icon → thumbnail preview of all windows for that app

### Out of scope for v0.1

- Alt-tab replacement (complex, many edge cases)
- Window history / undo snap
- Multi-monitor span layouts
- Integration with machNotch notch UI (Phase 2)

### Tech decisions

| Concern | Decision | Why |
|---------|----------|-----|
| Window enumeration | `CGWindowListCopyWindowInfo` | Public API, no entitlement |
| Window moving/resizing | `AXUIElement` via `NSAccessibility` | Only way to move other apps' windows |
| Drag detection for snapping | `NSEvent.addGlobalMonitorForEvents(.leftMouseDragged)` | No entitlement needed |
| Hover thumbnails | `CGWindowListCreateImage` | Public API, no Screen Recording entitlement needed for window thumbnails |
| Keyboard shortcuts | `KeyboardShortcuts` package (already in mach-mono) | Consistent with machNotch |
| Settings | `Defaults` package (already in mach-mono) | Consistent with machNotch |
| Menu bar presence | `NSStatusItem` | Standard macOS utility pattern |

**Required permissions:**

- `NSAccessibilityUsageDescription` — window move/resize via AXUIElement
- No Screen Recording needed for thumbnail peek

### Bazel integration

Add `machWindow` to `MODULE.bazel` and define `//Apps/machWindow:machWindow` in its `BUILD.bazel`. Shared packages (`KeyboardShortcuts`, `Defaults`) are vendored via Bazel — no duplicate resolution.

### Architecture

```
machWindow (menu bar app)
├── Core/
│   ├── WindowSnapEngine.swift      # AXUIElement snap logic
│   ├── SnapZoneDetector.swift      # Edge/corner detection during drag
│   └── ShortcutCoordinator.swift   # KeyboardShortcuts wiring
├── HoverPeek/
│   ├── DockHoverMonitor.swift      # NSEvent global monitor for Dock hover
│   ├── WindowThumbnailService.swift # CGWindowListCreateImage per app
│   └── HoverPeekWindow.swift       # Floating NSPanel showing thumbnails
├── Settings/
│   └── SettingsView.swift
└── machWindowApp.swift
```
