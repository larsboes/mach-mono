# boringNotch — PRD + Implementation Plan

**Goal:** Transform boringNotch from a polished notch replacement into a **local-first ambient display platform** — beautiful UX, API-driven extensibility, and a plugin ecosystem.

**Architecture:** Plugin-first + DI via ServiceContainer + @Observable/@MainActor throughout. Every feature is a plugin. Views never construct services. All cross-plugin communication via PluginEventBus.

**Tech Stack:** Swift 5.9+, SwiftUI/AppKit, Defaults (settings), Combine (publishers), XPC helper, Sparkle (updates), Lottie (animations), KeyboardShortcuts

**Build:** `xcodebuild -scheme boringNotch -destination 'platform=macOS' build 2>&1 | tail -50`
**Test:** `xcodebuild -scheme boringNotch -destination 'platform=macOS' test 2>&1 | tail -50`

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
- `private/CGSSpace.swift` — private API wrapper
- `mediaremote-adapter/` — pre-built framework, read-only

---

## Current State (2026-03-21)

**Working branch:** `developer`
**Branch sync:** `developer` = `origin/developer`, `main` = stable
**PR Status:** PR #1 Closed (Legacy). A new consolidated PR is pending architecture refinements.

| Phase | Status | Summary |
|-------|--------|---------|
| 1, 1b, 2, 3, 5, 6, 6b, 7 | ✅ Shipped | Core plugins, API Hardening, AI Assist, Automation, Battery & Export |
| 4 — Animation + Arch Debt | **Active** | 30+ items done. DDD directory restructure complete. Remaining: spring tuning, album art morph, gesture-driven open. |
| 9 — Third-Party Distribution | Planned | .boringplugin bundle format |
| 10 — Teleprompter Pro | **Active** | 10.0/10.4/10.7/10.8 shipped. Remaining: script library, voice scrolling, enhanced editor, display customization, closed display polish, screen sharing, detachable mode |
| 11 — Foundation Models | Planned | On-device AI via Apple FoundationModels (macOS 26+), streaming, structured generation |
| 12 — Audio Visualizer | **Active** | 12.1–12.6 shipped. 12.7 (perf budget measured, 2026-03-16). BUG-1 (realAudio not reactive) ✅ fixed. Active CPU: ~11% (over 3% target — SCK overhead; long-term fix: system audio tap API). |
| 13 — Notch Video Player | Planned (Long-term) | PiP-style video player as extended notch. AVPlayer + browser integration. |
| 14 — Animation & UI Polish | In Progress | Velocity-dependent springs, gesture feel, content morphing. |

### Phase 14 Status

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
| 4.28 | Docs | Fixed 5 doc discrepancies: ServiceContainer path in ARCHITECTURE.md, plugin registration location in PLUGIN_DEVELOPMENT.md, phantom Phase 8 in PRD, plugin count (8→12), BoringViewCoordinator status (legacy→active). Updated CLAUDE.md layer boundaries to distinguish domain vs coordinator files in Core/. |
| 4.29 | Sizing | `NotchSizeCalculator` restructured as single source of truth. `ClosedNotchInput` struct decouples calculator from services. `effectiveClosedNotchSize` moved from Observers to calculator. |
| 4.30 | Domain | `NotchAnimationStateProviding` + `createInput()` extracted from `NotchStateMachine.swift` to `ViewCoordinating.swift` (application layer). State machine is now domain-pure. |
| 4.31 | Safety | Force unwraps fixed in `Constants.swift`, `DownloadView.swift`, `BatteryService.swift`. |
| 4.32 | Cleanup | `NSObject` removed from `BoringViewModel`. NotificationCenter observers migrated to Combine publishers. |
| 4.33 | Cleanup | `BoringAnimations` collapsed from `@Observable` class to static enum. 29 unused `import Combine` removed. |
| 4.34 | DDD | **Directory restructure:** controllers/settings moved from `models/` → `Core/`. `SharingStateManager` → `Plugins/Services/`. `BoringViewModel` + extensions → new `ViewModel/` directory. `models/` now contains only pure data models. |
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
| 5.5 | API | **CLI companion** — `notchctl` shell script in `scripts/` wrapping REST API (`open`, `close`, `display`, `music`, `teleprompter`). |
| 5.6 | API | **REST endpoints** — full coverage: notch state/open/close/toggle, plugin list/detail/toggle, music now-playing/play-pause/next/previous. All plugin accesses wrapped in `MainActor.run`. |
| 5.7 | API | **Event enrichment** — WebSocket payloads now include event-specific data (track title/artist/album, battery level/charging, notch phase) instead of generic metadata. |
| 6.1 | Plugin | **TeleprompterPlugin** — camera-adjacent script scrolling. 6 API endpoints (load/start/pause/stop/state/ai-assist). Timer only fires when `isScrolling == true` (no idle 60fps overhead). `didSet` observer manages lifecycle. |
| 6.2 | Plugin | **DisplaySurfacePlugin** — generic ambient display accepting text/progress/markdown via API. TTL support with cancellable `Task`. 3 endpoints (text/progress/clear). |
| 6.3 | Infra | **Plugin route registration** — `apiRouteRegistrar` exposed on `NotchServiceProvider`. Plugins register routes in `activate()`, unregister in `deactivate()`. |
| 6b.1 | AI | **3-tier AI stack** — `AIProvider` (transport, `Sendable`) → `AITextGenerationService` (domain protocol, `@MainActor`) → `ProviderBackedAIService` / `NoAITextGenerationService`. |
| 6b.2 | AI | **Deterministic fallback** — `NoAITextGenerationService` throws clear errors with actionable install instructions. Default when AI disabled or no provider. |
| 6b.3 | AI | **OllamaProvider** — local LLM at `127.0.0.1:11434` with health check (`GET /api/tags`, 2s timeout), typed errors, 30s generation timeout. *(Phase 11: demoted to opt-in Advanced provider)* |
| 6b.4 | AI | **AIManager DI** — no singleton access. `isEnabled` injected as closure from settings. Exposes `textGeneration: any AITextGenerationService`. |
| 6b.5 | AI | **Domain methods** — `rewrite(_:style:)` (4 styles), `summarize(_:)`, `section(_:)`, `draftIntro(topic:durationSeconds:)`. Prompt engineering encapsulated in `ProviderBackedAIService`. |
| 6b.6 | AI | **Teleprompter AI** — type-safe `TeleprompterAIAction` enum (refine/summarize/draft-intro). `DecodingError` returns 400 with valid options. |
| 6b.7 | AI | **Settings DI** — `isAIEnabled` added to `GeneralAppSettings` protocol + `DefaultsKeys.enableAI` + `MockNotchSettings`. No singleton reads. |
| 6b.8 | AI | **Service protocol** — `NotchServiceProvider.ai` typed as `any AITextGenerationService` (not concrete `AIManager`). `ServiceContainer` wires via `AIManager.textGeneration`. |
| 7.1 | Automation | **App Intents** — `OpenNotchIntent` + `CloseNotchIntent` routed through `NotificationCenter` bridge to `BoringViewModel`. No singleton coupling. |
| 7.2 | Automation | **URL scheme** — `boringnotch://` open/close/toggle/plugins. Toggle checks `vm.notchState` for correct dispatch. Registered via `NSAppleEventManager` in AppDelegate. |
| 7.3 | Automation | **Intent bridge** — `BoringViewModel.setupIntentObservers()` observes `.openNotchIntent` / `.closeNotchIntent` on main queue with `[weak self]`. |
| 10.0 | Teleprompter | **Expanded panel redesign** — full-width two-column layout (editor left ~60%, control panel right ~40%). `TeleprompterControlPanel.swift` extracted. Speed controls, font size slider, 5 text color swatches (`PrompterColor` enum), AI actions, script info (word count, reading time, sections). Bottom action bar with Present CTA. |
| 10.3 | Teleprompter | **Voice visual feedback (partial)** — `MicrophoneMonitor` + linear gradient beam in `TeleprompterClosedView`. Responds to RMS level with spring animation. Remaining: radial arc shape, configurable color/opacity. |
| 10.4 | Teleprompter | **Countdown timer** — `CountdownState` (tick-based, configurable 0/3/5s) + `CountdownOverlayView` (cinematic scale+fade numbers, tap-to-cancel). Wired into `startPresentation()` flow. Overlay renders in closed view during countdown. |
| 10.7 | Teleprompter | **Hover-to-pause** — `.onHover` on `TeleprompterClosedView` pauses/resumes scrolling. `isHovering` state in `TeleprompterState`. Remaining: visual pause indicator overlay. |
| 10.8 | Teleprompter | **Keyboard shortcuts** — `TeleprompterShortcutHandler` with 5 user-configurable shortcuts (play/pause, speed up/down, reset, go home). Registered in plugin `activate()`, unregistered in `deactivate()`. |
| 10.10 | Teleprompter | **Improved closed display (partial)** — text centered under camera, full-width reading zone, voice beam, smooth per-pixel scroll. Remaining: karaoke fade, progress bar, section title, elapsed/remaining time. |
| 4.29 | Arch Debt | **SRP: TeleprompterTimerManager** — Extracted timer/mic lifecycle from `TeleprompterState` into dedicated `TeleprompterTimerManager`. State class now owns only scroll position, config, and domain logic. |
| 4.30 | Arch Debt | **SRP: DisplayPrioritizer** — Extracted display arbitration from `PluginManager` into pure `DisplayPrioritizer` struct. PluginManager delegates via `DisplayPrioritizer.highestPriority(among:)`. |
| 4.31 | Arch Debt | **SRP: HeaderButton** — Extracted `HeaderButton`/`HeaderActionButton` components from `BoringHeader`. Header reduced from 197→130 lines, eliminated 5x copy-paste button boilerplate. Sub-views: `leadingContent`, `notchOverlay`, `trailingControls`, `headerButtons`. |
| 4.32 | Arch Debt | **Clean Code: ContentView sub-views** — Extracted `notchBackground`, `glassOverlay`, `topEdgeLine` from 175-line body into computed views. |
| 4.33 | DDD | **PluginID enum** — Centralized all 30+ stringly-typed plugin identifiers into `PluginID` constants. All plugins, routers, event emitters, and settings views now use type-safe references. |
| 4.34 | DDD | **SneakContentType.isHUD** — Moved HUD-type check from free function in BoringHeader to computed property on enum (domain logic on domain type). |
| 4.35 | Clean Code | **DisplaySurfaceState** — Made `ttlTask` private, added `[weak self]` capture, added explicit `clear()` method. |
| 4.36 | Clean Code | **Named constants** — `TeleprompterState` magic numbers extracted: `endBuffer` (40px), `speedStep` (10), `speedMin` (10), `speedMax` (150). |
| 4.37 | Performance | **Background TimelineView gating** — `PluginMusicControlsView` `TimelineView(.animation)` now switches to static `HStack` when notch is closed. Eliminates 60fps background CPU burn. |
| 4.38 | Performance | **AVAudioRecorder lifecycle** — `MicrophoneMonitor` mic hardware release tied to `onDisappear`/`notchState` change. Orange dot no longer persists when teleprompter is paused. |
| 4.39 | Performance | **Eliminate `AnyView`** — Plugin views migrated from `AnyView` to type-specific wrappers, restoring SwiftUI structural identity for diff-based updates. |
| 4.40 | Performance | **Isolate high-frequency readers** — `elapsedTime` decoupled from `PluginMusicControlsView` into leaf `ScrubberPlayheadView`. Only playhead redraws at 60fps. |
| 4.41 | Performance | **GPU/CoreAnimation backoff** — Heavy `.blur(radius: 35)` and `.blendMode(.screen)` gated behind `!vm.phase.isTransitioning`. |
| 4.42 | Performance | **Background service suspension** — `BackgroundServiceRestartable` protocol + `BoringViewModel.phase` observer pauses `BatteryService`/`BluetoothManager` polling when notch closed. `NotchServiceProvider` consolidation. |
| 4.43 | Performance | **Teleprompter off-main parsing** — `TeleprompterState.text` `didSet` now parses sections via `Task.detached`, caching results instead of re-parsing 60× per second on MainActor. |
| 4.44 | Performance | **Aggressive @Observable Invalidation** — Decoupled high-frequency progress updates (currentTime/duration) into isolated publishers (Phase 2 efficiency). |
| 4.45 | Performance | **Window Coordinator Geometry** — Replaced 150ms polling loop with `CGDisplayRegisterReconfigurationCallback` hardware event handling. |
| 4.46 | Performance | **XPC Reconnection Backoff** — Implemented exponential backoff in `XPCHelperClient` to prevent CPU-intensive reconnection loops on crash. |

---

## Known Architecture Debt (Tracked)

Issues identified during comprehensive review (2026-03-08). Documented here for future phases.

### DIP: BoringViewModel → concrete BoringViewCoordinator

**Severity:** Medium | **Files:** 22 reference `BoringViewCoordinator` concretely | **Effort:** High

`BoringViewModel.coordinator` is typed as `BoringViewCoordinator` (concrete), not a protocol. Same for `ContentView`, `NotchContentRouter`, and `BoringHeader` via `@Environment`. Abstracting requires a `@Bindable`-compatible protocol, which SwiftUI doesn't natively support for existentials. Would require either:
- A `@Bindable`-aware wrapper type
- Or splitting coordinator into read-only protocol + mutation methods

**When to fix:** When `BoringViewCoordinator` needs to be testable in isolation, or if a second coordinator implementation is needed.

### ISP: Fat NotchServiceProvider (28 properties)

**Severity:** Medium | **Files:** `NotchServiceProvider.swift`, all plugin `activate()` methods | **Effort:** High

A timer plugin needing only `sound` + `notifications` must depend on 28 services including `bluetooth`, `weather`, `brightness`. Should be split into focused sub-protocols:
- `MediaServices` (music, lyrics, sound)
- `SystemServices` (volume, brightness, battery)
- `StorageServices` (shelf, temporary files, sharing)
- `UIServices` (notifications, quicklook)
- `FullServiceProvider` (union for backward compat)

**When to fix:** When adding third-party plugin support (Phase 9) — external plugins should not see internal services.

### ISP: Fat CoordinatorSettings

**Severity:** Low | **Files:** `NotchSettingsSubProtocols.swift:182-186` | **Effort:** Medium

`CoordinatorSettings` composes 6 sub-protocols (`GeneralAppSettings`, `HUDSettings`, `MediaSettings`, `AppearanceSettings`, `DisplaySettings`, `ShelfSettings`) but the coordinator only uses ~5 properties from them. Should be narrowed to actual usage.

**When to fix:** Next settings refactor pass or when adding new coordinator implementations.

---

> The items below were added during the 2026-03-23 architecture audit (3 parallel agents, 333 files analyzed).

### Layer Violation: MusicManager.isNowPlayingDeprecatedStatic Leaks Across Layers

**Severity:** Medium | **Files:** 4 files outside `Plugins/Services/` | **Effort:** Low

`MusicManager.isNowPlayingDeprecatedStatic` (concrete infra type) is accessed directly in:
- `Core/DefaultsKeys.swift:164` — application layer calling into concrete infra
- `components/Settings/Views/MediaSettingsView.swift:31, 146` — presentation calling concrete infra
- `components/Onboarding/MusicControllerSelectionView.swift:16` — presentation calling concrete infra

All 4 use it to detect whether the NowPlaying API is deprecated (macOS version check). The correct pattern is a protocol abstraction (e.g., `MediaControllerCapabilityProtocol`) injected via settings or service provider.

**When to fix:** Phase 15 — low-effort, high-clarity win.

### OCP Violation: NotificationsPlugin Casts to Concrete ServiceContainer

**Severity:** Medium | **Files:** `Plugins/BuiltIn/NotificationsPlugin/NotificationsPlugin.swift:51` | **Effort:** Low

```swift
if let container = context.services as? ServiceContainer {
```

Downcasts the protocol-typed `context.services` to the concrete `ServiceContainer`. If `ServiceContainer` is ever renamed, split, or mocked, this breaks silently. The required service should be added to the relevant `ServiceProvider` sub-protocol instead.

**When to fix:** Phase 15 — 1-line fix, high DI cleanliness.

### SRP: BoringViewModel is a God Object (704 lines, 8+ responsibilities)

**Severity:** Medium | **Files:** `ViewModel/BoringViewModel.swift` + 4 extension files | **Effort:** High

Total 704 lines across `BoringViewModel.swift` (269), `+Observers.swift` (171), `+OpenClose.swift` (130), `+Hover.swift` (76), `+Camera.swift` (58). Responsibilities span: per-screen phase state, sizing delegation, hover detection, camera expansion, drop targeting, animation progress tracking, service dependencies, and observer lifecycle.

**Decomposition path:**
- `NotchPhaseCoordinator` — open/close logic, phase state, watchdog tasks
- `NotchAnimationOrchestrator` — contentRevealProgress, shellAnimationProgress
- `DropTargetingManager` — drag/drop state (`dragDetectorTargeting`, `generalDropTargeting`, `dropZoneTargeting`)
- `CameraFaceManager` — `isCameraExpanded`, `isRequestingAuthorization`
- `BoringViewModel` (residual, <150 lines) — sizing delegation, service access, wiring

**When to fix:** When any single responsibility needs independent testability, or when complexity slows feature work. Not urgent — extension files keep it manageable today.

### OCP Violation: PluginManager+ViewHelpers Requires Modifying for Every New Plugin

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

### ISP: Service Contracts Not Enforced at Compile Time

**Severity:** Low | **Files:** All `activate()` methods | **Effort:** High

ISP sub-protocols (`MediaServiceProvider`, `SystemServiceProvider`, etc.) exist on `NotchServiceProvider` but plugins receive the full union and can access any service. A `WeatherPlugin` can call `context.services.bluetooth` without restriction. Trust-based enforcement is fine for built-in plugins, but will be a liability for Phase 9 third-party plugins.

**When to fix:** Phase 9 — external plugins must receive scoped service access.

### Hard-Coded Plugin Registration in AppObjectGraph

**Severity:** Low | **Files:** `AppObjectGraph.swift` | **Effort:** Medium

Built-in plugins are instantiated eagerly as a hardcoded array in `AppObjectGraph`. No lazy loading, no conditional activation based on hardware capability, no discovery mechanism. Manageable for built-ins, but precludes dynamic plugin loading required for Phase 9.

**When to fix:** Phase 9.

---

---

## Phase 4 — Animation Polish + Architecture Debt (Active)

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

Replace fire-and-forget animations with continuous gesture-driven expansion. Notch height/width maps 1:1 to gesture translation — interruptible and scrubbable. Substantial refactor of `BoringViewModel+OpenClose`. Defer until Tasks 16-20 shipped.

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

**CLI:** `notchctl open|close|display|music|teleprompter` — shell script in `scripts/`.

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
                            └── OllamaProvider (opt-in, Advanced settings only)
```

**Hard rule:** AI is assistive only. No core plugin workflow depends on AI availability.

**DI:** `NotchServiceProvider.ai → any AITextGenerationService`. `ServiceContainer` wires via `AIManager(isEnabled: { settings.isAIEnabled }).textGeneration`. No singletons.

### AI Provider Strategy

- **Primary:** Apple Foundation Models (macOS 26+). On-device, zero config, zero install, fully private. Covers the teleprompter sweet spot (summarization, rewriting, extraction).
- **Optional/Advanced:** Ollama for power users who want larger/specialized models. Hidden behind "Advanced AI Settings" toggle. Not registered unless explicitly enabled.
- **Fallback:** `NoAITextGenerationService` — clean degradation. On macOS <26 or unsupported hardware, AI features simply don't appear in the UI. No "install Ollama" messaging.

**Migration:** `OllamaProvider` to be removed from default `AIManager.init()` registration. Foundation Models becomes the sole default provider. See Phase 11 for implementation details.

### Remaining AI plugin opportunities

- **DisplaySurface:** summarize long pushed content into notch-safe cards
- **Notifications:** merge notification bursts into "what matters now" digests
- **Clipboard:** rewrite/clean copied text, extract action items
- **Calendar:** compact "next up" meeting briefs

---

## Phase 7 — Automation & Integrations ✅

**App Intents:** `OpenNotchIntent`, `CloseNotchIntent` — Shortcuts-compatible, NotificationCenter bridge.
**URL Scheme:** `boringnotch://open|close|toggle|plugins?id=...` — registered via `NSAppleEventManager`.
**Bridge:** `BoringViewModel.setupIntentObservers()` on main queue with `[weak self]`.

---

## Phase 9 — Third-Party Plugin Distribution

**Goal:** `.boringplugin` bundle format + plugin discovery UI.

**Separate design document when Phase 7 is complete.**

Requirements: signed Swift package bundles, permission manifests, approval UI, plugin browser in Settings, `~/Library/Application Support/boringNotch/Plugins/` discovery.

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
- AI assist (refine/summarize/draft-intro) via Ollama only
- Closed view: centered text with voice beam + hover-to-pause (functional)
- No script management, no mode selection, no progress indicators

**What's missing for professional use:** script library, voice-driven scrolling, visual feedback polish, calibration, rich editing, display customization, detachable mode, and on-device AI that works without installing Ollama.

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

**Why this matters:** The current AI stack requires Ollama (manual install, ~4GB download, must be running). Foundation Models is built into macOS 26 — it just works. This makes AI features accessible to 100% of users on supported hardware, not just developers who know what Ollama is.

### Architecture

The existing 3-tier AI stack (`AIProvider` → `AITextGenerationService` → `ProviderBackedAIService`) was designed for this. `FoundationModelsProvider` becomes the sole default provider.

```
AIManager
├── FoundationModelsProvider  ← PRIMARY (macOS 26+, zero config, on-device)
├── OllamaProvider            ← OPT-IN (Advanced settings toggle, power users only)
└── NoAITextGenerationService ← FALLBACK (macOS <26 or unsupported hardware)

Default: Foundation Models (if macOS 26+) > NoAI
Advanced: User explicitly enables Ollama → Ollama (if running) > Foundation Models > NoAI
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

Replace current Ollama-default `AIManager.init()` with Foundation Models-first strategy:

```swift
init(isEnabled: @escaping () -> Bool = { true }, ollamaEnabled: @escaping () -> Bool = { false }) {
    self.isEnabledProvider = isEnabled
    self.ollamaEnabledProvider = ollamaEnabled

    // Primary: Foundation Models (macOS 26+, zero config)
    if #available(macOS 26, *) {
        registerProvider(FoundationModelsProvider())
        activeProviderId = "foundation-models"
    }

    // Ollama ONLY if user explicitly opts in via Advanced settings
    // Not registered by default — no "install Ollama" messaging anywhere
}

/// Called when user enables Ollama in Advanced AI Settings
func enableOllama(model: String = "llama3", host: String = "http://127.0.0.1:11434") {
    registerProvider(OllamaProvider(model: model, host: host))
    // Ollama takes priority when explicitly enabled (user wants bigger models)
    activeProviderId = "ollama"
}

func disableOllama() {
    providers.removeValue(forKey: "ollama")
    // Fall back to Foundation Models or NoAI
    if #available(macOS 26, *) {
        activeProviderId = "foundation-models"
    } else {
        activeProviderId = nil
    }
}
```

**Feature gating:** On macOS <26 without Ollama enabled, AI action buttons simply don't render. No error states, no "upgrade macOS" messaging — the feature just isn't there. Clean absence > broken presence.

**Availability resilience:** Foundation Models may report `.available` at init but fail later (model downloading, etc.). The `generate()` call catches errors and surfaces them per-request — no automatic fallback to Ollama unless user explicitly configured it.

### 11.7 — AI Settings UI

**Status:** Planned

**Main AI Settings (visible to all users on macOS 26+):**
- AI enable/disable toggle
- AI availability indicator (green dot = Foundation Models ready)
- "Test AI" button — sends a sample prompt and shows response

**Advanced AI Settings (collapsed/hidden section):**
- "Use custom AI provider (Ollama)" toggle — off by default
- When enabled:
  - Ollama model name (default: `llama3`)
  - Ollama host (default: `127.0.0.1:11434`)
  - Connection status indicator
  - "Ollama takes priority over Apple Intelligence when enabled" note
- Link to Ollama docs for installation

**On macOS <26:** AI settings section shows "AI features require macOS 26 or later" with the Advanced section still available for Ollama opt-in.

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
| **P1** | 11.6 Auto-select provider | 11.1 | Seamless provider switching |
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

**Key constraint:** `ScreenCaptureKit` requires macOS 13+. On macOS 12, fall back to fake animation silently.

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
- `MeshGradient` (macOS 15+) or layered `LinearGradient` fallback
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

**Root cause:** `AudioFFTProcessor.process` required `samples.count >= 1024` but SCK delivers ~512-sample buffers (macOS system audio device default). Every single incoming buffer was silently dropped via `guard samples.count >= fftSize else { return }`.

**Secondary issue:** `AudioSpectrum.updateBands` had `peak > 0.08` threshold that silenced quiet audio in the 4-bar notch indicator. Lowered to `0.01`.

**Fix:**
- `AudioFFTProcessor.swift` — Added `sampleAccumulator: [Float]`. `process()` now appends samples and processes once ≥ 1024 are available. Uses 50% overlap (advances by 512) for better time resolution. Accumulator is capped to prevent memory growth.
- `MusicVisualizer.swift` — Lowered `peak` threshold from `0.08` → `0.01`.

---

### BUG-2 — Notch Expands Horizontally ~3s Then Snaps Back

**Status:** ⚠️ Open (confirmed present as of 2026-03-23 audit)

**Symptom:** Notch randomly widens (horizontally) for ~3 seconds then returns to normal size.

**Root cause (traced):** `KeyboardShortcutCoordinator` opens the notch and schedules a `Task.sleep(3s)` auto-close (`KeyboardShortcutCoordinator.swift:100`: `try? await Task.sleep(for: .seconds(3))`). During those 3 seconds, `NotchObserverSetup` fires a `hideOnClosed` change (triggered by `FullscreenMediaDetector.fullscreenStatus`). This causes `BoringViewModel.effectiveClosedNotchSize` to recalculate — and if `isMusicActive || isFaceActive` is true, extra width is added/removed with a `.smooth` animation. The 3s timer then fires `viewModel.close()` snapping it back.

**Key files:**
- `KeyboardShortcutCoordinator.swift:100` — `try? await Task.sleep(for: .seconds(3))` auto-close
- `BoringViewModel+Observers.swift:16–36` — `hideOnClosed` setter triggers `.smooth` animation
- `BoringViewModel+OpenClose.swift:65–68` — `effectiveClosedNotchSize` snapshot taken at close-start
- `Core/NotchObserverSetup.swift:42–73` — hideOnClosed observer loop (unstructured Task, no cancellation)

**Fix direction (two options, pick one):**
1. **Suppress width recalculation during keyboard open:** Gate `effectiveClosedNotchSize` width additions on `phase == .closed` — don't add ear-width while notch is open/transitioning
2. **Cancel hideOnClosed debounce on `.opening`:** `BoringViewModel+OpenClose.swift` already cancels `hideOnClosedDebounceTask` on `open()` — verify this fires before the fullscreen observer can race in

---

### BUG-3 — AudioFFTProcessor Force Unwrap Crash Risk

**Status:** ⚠️ Open

**Location:** `Plugins/Services/AudioFFTProcessor.swift:40`

```swift
self.fftSetup = vDSP_create_fftsetup(n, FFTRadix(kFFTRadix2))!
```

**Risk:** If vDSP setup fails (memory pressure, invalid params), the app crashes on audio service init. No recovery path. Replace `!` with `guard let` + graceful degradation to simulated mode.

---

### BUG-4 — Unstructured Observer Tasks in NotchObserverSetup Have No Cancellation

**Status:** ⚠️ Open

**Location:** `Core/NotchObserverSetup.swift:46–72`

Two `Task { @MainActor in }` blocks launched in `setupDetectorObserver()` are never stored or cancelled. If `NotchObserverManager` deallocates, these tasks continue running and invoking the callback. The `[weak self]` capture prevents crashes but leaves zombie observers polling indefinitely.

**Fix:** Store task references as properties, cancel in `deinit`.

---

### BUG-5 — Recursive Observation Accumulation in startEarsTracking

**Status:** ⚠️ Open

**Location:** `ViewModel/BoringViewModel+Observers.swift:57–64`

`startEarsTracking()` sets up a new `withObservationTracking` block each time it's called, then calls itself recursively from the `onChange` handler. Every ears state change creates a new observation without cleaning up the previous one. Over time with frequent music state changes, observations accumulate.

**Fix:** Guard with `earsTrackingActive` flag or store the tracking handle for cleanup before re-subscribing.

---

### BUG-6 — Silent try? Swallows Task Cancellation Signal

**Status:** Low-severity pattern, 4+ locations

**Locations:**
- `Core/KeyboardShortcutCoordinator.swift:100`: `try? await Task.sleep(for: .seconds(3))`
- `ViewModel/BoringViewModel+OpenClose.swift:91`: `try? await Task.sleep(for: .milliseconds(300))`

`try?` on `Task.sleep()` silently swallows `CancellationError`, making it impossible to determine if the sleep completed normally or was cancelled. Correct pattern:
```swift
guard !Task.isCancelled else { return }
try await Task.sleep(for: .seconds(3))
```

---

### BUG-7 — @unchecked Sendable on AudioFFTProcessor Without Synchronization

**Status:** ⚠️ Low-severity data race risk

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
| **Presentation** | ⚠️ 6.5/10 | `NotchContentRouter` is clean. `BoringViewModel` is a god object (704 lines, 8 responsibilities). `PluginManager+ViewHelpers` has OCP-violating switch. 3 view files access concrete `MusicManager`. |

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
| **P2** | Extract `NotchPhaseCoordinator` from `BoringViewModel` | Medium | SRP, testability |
| **P3** | Enforce ISP service contracts on `PluginContext` generics | High | Compile-time safety for Phase 9 |
| **P3** | Separate plugin factory from `AppObjectGraph` | High | Enables Phase 9 dynamic loading |

### Plugin System Score: 7.5/10

| Dimension | Score | Note |
|-----------|-------|------|
| Plugin Isolation | 8.5/10 | Event bus prevents coupling; discovery is hardcoded |
| DI Completeness | 7.5/10 | PluginContext solid; service access trust-based not enforced |
| Presentation Clarity | 6.5/10 | ContentRouter excellent; BoringViewModel bloated |
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

**Priority:** P0 | **Effort:** Low | **Files:** `KeyboardShortcutCoordinator.swift`, `BoringViewModel+OpenClose.swift`

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

**Priority:** P1 | **Effort:** Low | **Files:** `NotchObserverSetup.swift`, `BoringViewModel+Observers.swift`

- Store Task references in `NotchObserverManager`, cancel in `deinit`
- Fix recursive `startEarsTracking()` with active-flag guard
- Add `deinit` to `BoringViewModel` cancelling `hideOnClosedDebounceTask`, `earsDebounceTask`, `closeWatchdogTask`, `postCloseHoverTask`

### 15.6 — Type-Erase PluginManager+ViewHelpers Switch

**Priority:** P2 | **Effort:** Medium | **Files:** `Plugins/UI/PluginManager+ViewHelpers.swift`, `AnyNotchPlugin`

Extend `AnyNotchPlugin` with type-erased `closedNotchContentView()`, `expandedPanelContentView()`, `settingsContentView()` → `AnyView`. Remove the `switch id { case PluginID.music: ... }` pattern. Required before Phase 9 (external plugins cannot be listed in a switch).

### 15.7 — Extract NotchPhaseCoordinator from BoringViewModel

**Priority:** P2 | **Effort:** Medium | **Files:** `BoringViewModel+OpenClose.swift` → `Core/NotchPhaseCoordinator.swift`

Extract open/close state machine + watchdog tasks into a dedicated `@MainActor @Observable` class. `BoringViewModel` delegates to it. Reduces BoringViewModel responsibility count from 8 to 7, makes open/close independently testable.

### Phase 15 Implementation Order

| Priority | Task | Effort | Unblocks |
|----------|------|--------|---------|
| **P0** | 15.1 Fix BUG-2 | Low | UX stability |
| **P1** | 15.2 Abstract MusicManager static | Low | Layer purity |
| **P1** | 15.3 Fix NotificationsPlugin cast | Low | DIP compliance |
| **P1** | 15.4 AudioFFTProcessor safety | Low | Crash prevention |
| **P1** | 15.5 Fix observer tasks | Low | Memory leak prevention |
| **P2** | 15.6 Type-erase ViewHelpers switch | Medium | Phase 9 |
| **P2** | 15.7 Extract NotchPhaseCoordinator | Medium | BoringViewModel SRP |

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
| 6b | ✅ **Done.** 3-tier AI architecture. Domain protocol with deterministic fallback. No singleton access. Prompt engineering encapsulated. *(Phase 11: Ollama demoted to opt-in, Foundation Models becomes primary.)* |
| 7 | ✅ **Done.** App Intents in Shortcuts. URL scheme routes work (including toggle). |
| 9 | External plugin loads from ~/Library/Application Support/boringNotch/Plugins/. |
| 10 | Expanded panel uses full 740px with two-column layout (editor + controls). Script library persists named scripts. Countdown timer works. Keyboard shortcuts for hands-free control. Closed display shows 2–3 lines with karaoke fade, progress bar, elapsed/remaining time. Voice-driven scrolling as optional Flow Mode. Screen sharing safety via `sharingType = .none`. Detachable floating window for external displays. Creator-daily-driver quality. |
| 11 | `FoundationModelsProvider` is sole default provider on macOS 26+. AI features work with zero external dependencies. Ollama available as opt-in Advanced option only. Streaming AI responses in teleprompter UI. Structured generation via `@Generable`. On macOS <26: AI features cleanly absent (no broken states). |
| 12 | Real audio-reactive visualizer responds to actual system audio. Extended notch height configurable. Album art color extraction for theming. Idle: 3% CPU (✅). Active: ~11% CPU (⚠️ over target — SCK framework overhead; long-term fix: system audio tap API). Permission denial degrades gracefully to simulated animation. |
| 13 | Video plays in notch viewport via AVPlayer. YouTube URLs load via yt-dlp. Hover reveals mini controls. Expanded panel has full controls + URL input. <5% CPU at 720p. Browser extension video integration validated or descoped. |
| 15 | BUG-2 never reproduces. Zero concrete `MusicManager` refs outside infra layer. `AudioFFTProcessor` crash-free with `@MainActor`. All observer Tasks stored + cancellable. `PluginManager+ViewHelpers` has no plugin switch statements. DDD compliance at 90%+. |
