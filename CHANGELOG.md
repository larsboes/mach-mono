# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

For upcoming features see the [Roadmap](https://larsboes.github.io/mach-mono/roadmap).

---

## Unreleased

Work merged to `main` since v1.3.2. Not yet tagged or released.

### 🏗 Architecture

* **Migrated off Bazel to [Tuist](https://tuist.dev)** (2026-08-30): `Project.swift` manifests replace `BUILD.bazel`; the `.xcodeproj`/`.xcworkspace` are generated output and gitignored. Xcode is a first-class build and debug entrypoint again. The plugin-per-module boundary and the Soundscape opt-in split carry over. Rationale and what Bazel cost are in [`Roadmap.md`](Roadmap.md).
* **Coexistence with third-party apps**: a `PluginDescriptor` can declare that an installed third-party app already covers its job. `shelf`, `clipboard`, `webcam` and `systemStats` declare an overlap with Vorssaint. Detection is metadata-only and never changes plugin state. See [`Architecture.md`](Architecture.md).
* **Launch cost**: `ServiceContainer` dependencies are `lazy var`, so a disabled plugin no longer builds its services at launch. Covered by `LaunchCostTests`.
* **Typed `PluginEventBus`**: dispatch map keyed by `ObjectIdentifier` replaces the previous subscription lookup.
* **machNotch architecture hardening** (2026-06-13): app `@main` shim split, per-plugin build targets, app-facing plugin facade bridges, strict descriptor-based on-demand plugin loading, and default AudioKit-free builds with Soundscape behind an explicit opt-in target.

### 🩺 Health & Intelligence

* **Semantic shelf search actually works.** `SQLiteVecIndex.upsert` inserted against a filtered query — not a valid INSERT target — so every insert threw and `ShelfSemanticSearchService` silently fell back to substring matching. Fixed.
* **Vector query is ~100x faster.** Top-5 over 10k vectors went from 1239 ms to 12 ms. Queries are answered from an in-memory mirror holding L2-normalized vectors in one flat buffer, so each comparison is a single `vDSP_dotpr`; the database is no longer read per query.
* **Shelf re-indexing is incremental.** Items carry a hash of the text they were indexed from, stored on the record so it survives a restart. An unchanged shelf now costs zero embedding calls instead of one per item per search.
* **SystemStats gained a GPU ring**, read from the busiest IOAccelerator's `PerformanceStatistics`. Sampling moved to `SystemStatsSampler`, which reports nil rather than zero when a source has no reading, so a failed syscall no longer draws as "idle". `refreshInterval` is now clamped on read as well as write.
* **machHealth export is at-least-once.** `HealthExportQueue` keeps a payload until the send succeeds, backs off 2s/4s/8s capped at five minutes, and persists on every change. Exhausted entries are kept rather than deleted. `HealthAnchorStore` persists one HealthKit anchor per metric type. Schema v1 is now documented at [/health/schema-v1](https://larsboes.github.io/mach-mono/health/schema-v1).

### 🔌 Plugin SDK

* **Public API frozen and published.** `NotchPluginCore` is the SDK product — protocol, context, descriptor — and depends on no plugin. Docs at [/plugins/overview](https://larsboes.github.io/mach-mono/plugins/overview).
* **Capability narrowing is enforced.** `PluginContext`'s service accessors return facades that conform to a single sub-protocol, so a plugin holding `mediaServices` can no longer cast back up to `NotchServiceProvider` and reach clipboard, calendar or webcam. An external plugin receives only the groups its `PluginDescriptor` declares; reaching for another traps at activation.
* **`DisplayCategory` constants moved onto `DisplayCategory`.** Call sites read `category: .music` instead of `category: DisplayRequest.music`.
* **`examples/HelloPlugin`** builds and tests with plain `swift build`. `task sdk:example` runs it.

### 🐛 Build Fixes

Found by building the example against the SDK. All pre-existing, and all invisible to the Xcode build:

* `NotchCore`, `NotchPlugins`, `NotchServices`, `NotchUI` and `MachSoundKit` declared `.macOS(.v14)` while depending on macOS 26 packages, so their SwiftPM manifests could not resolve.
* `NotchSettingsMacro` had no `Package.swift` at all, unlike every other package, so `NotchCore` could not build outside Tuist.
* Every package target now pins `.swiftLanguageMode(.v5)`, matching the `SWIFT_VERSION = 5.0` that `Tuist/ProjectDescriptionHelpers/Mach.swift` already sets.
* `MachBriefKit` shipped a hand-written `Bundle+Module.swift` that collided with the accessor SwiftPM generates for its declared resources.

### ✨ New Features

* **Semantic shelf search** backed by oMLX embeddings, through `MachIntelligenceKit`.
* **machBrief menu bar v1** experience completed; iOS v2 intent contracts prepared in the app layer.

### 🐛 Bug Fixes

Found during the Bazel-to-Tuist migration, all pre-existing:

* The XPC helper's bundle id never matched `XPCHelperClient.serviceName`, so the privileged helper could not connect in a Bazel build. Restored to the value the committed Xcode project used.
* `AudioKit` and `SoundpipeAudioKit` were declared dependencies with no first-party imports. Dropped.
* `PomodoroTimerTests` read and wrote the user's real `~/Library/Application Support/machNotch/pomodoro.json`. Bazel's sandbox hid it. The store is now injectable and the tests use a temp file.

### ⚙️ CI & Tooling

* `task` replaces the Bazel wrappers as the canonical command surface. `task --list` prints every command.
* `task verify:no-soundscape` inspects the built binary with `nm` and `otool` instead of querying the build graph, so it tests the artifact that ships.
* Test and coverage artifacts are uploaded from CI; the website build is a reusable composite action.
* **License**: MIT-migration slice reauthored sizing, media keys, fullscreen and home/extras.

---

## v1.3.2 — 2026-05-16

> **Note:** v1.3.1 was tagged on 2026-05-15 but its release build failed at codesign and produced no artifact. v1.3.2 supersedes it.

### 🐛 Bug Fixes

* **Teleprompter UI cleanup (closes #11)**: Final polish — extracted `5.5` reading-area magic number to `readingAreaHeightMultiplier` static; moved `ActionBarSecondaryStyle` from `TeleprompterExpandedView.swift` to `TeleprompterControlPanel.swift`. Wraps up the broader cleanup tracked across prior polish sessions.

### ⚙️ CI & Compatibility

* **Codesign path fixed**: Release workflow now points at `bazel-bin/Apps/machNotch/machNotch_archive-root/machNotch.app` (the actual `rules_apple` bundle output). Root cause of the v1.2.0, v1.3.0, and v1.3.1 release-build failures.
* **Release dry-run on every `main` push**: Catches packaging/codesign regressions before tag time instead of at release.
* **Release SHA == build SHA**: Release job now uses the same commit SHA the build was produced from; eliminates split-state releases.
* **Concurrency hardening**: `cancel-in-progress: false` on release workflows prevents partial/superseded runs from publishing.
* **Tag pattern restricted to semver**: Only `vX.Y.Z` triggers the release pipeline.
* **Arch-check script SRC path corrected**: Previously pointed at a non-existent path and silently always passed; now actually validates the source tree.
* **Bazel cache consolidation**: Unified Bazel cache keys across CI jobs; added Bazelisk binary cache to cut cold-start time.
* **swift-format strict mode**: Baseline cleared and strict mode enforced in CI.
* **CodeQL Swift muted**: Moved to manual `workflow_dispatch` — incompatible with Bazel + `rules_swift` on macOS. Shared Xcode scheme restored for the manual path.
* **`build_reusable.yml` permissions tightened**: Dropped write permission; reusable build job is read-only.
* **Line-count allowlist**: Three files that tipped over the 300-line threshold from the swift-format pass added to the allowlist (tracked for follow-up extraction).

---

## v1.3.0 — 2026-05-10

### 🏗 Architecture

* **PluginUIContext**: New environment type introduced to resolve DIP violations — plugin views no longer import or depend on `NotchViewModel` directly. All built-in plugin views migrated to `PluginUIContext`.

### ✨ New Features

* **mach.brief Phase 1**: App Group infrastructure for cross-app settings sync between machNotch and mach.brief.
* **mach.brief Phase 2**: Vocabulary level system with in-app onboarding picker; 4-panel hover expanded view with vocab as default tab.
* **mach.brief offline**: Word cache, offline fallback, and expanded word lists so the app works without a network connection.
* **Bazel native build**: Full migration to native Bazel rules for machNotch and the XPC service bundle. `Taskfile.yml` replaces the Makefile.

### 🐛 Bug Fixes

* **Permissions**: Bluetooth permission prompt suppressed on launch; persistent TCC/accessibility sentinel prevents repeat prompts across installs.
* **Calendar**: Compact access prompt fits within the widget height; grant button always visible regardless of auth state.
* **Stats**: Guarded `UInt64` underflow in `readNetworkRates` that caused a crash on rapid interface changes.
* **mach.brief**: Prevented notch stuck-state from slow API calls and rapid reloads; fixed word language setting not applying to quote source.

### ⚙️ CI & Compatibility

* **macOS 26**: Switched CI to `macos-26` runner; fixed XCTest async teardown crashes across `MusicPluginTests`, `QuickShareService`, and `BriefPlugin` test suites.
* **Bazel CI**: Repaired pipeline; split Bazel cache by target; `--jobs=HOST_CPUS`; `actions/checkout@v5`.

---

## v1.2.0 — 2026-05-03

First public release.

### 🧹 Repo Hygiene

* **Root README refresh**: Updated root documentation from stale `machNotch` paths to the current `Apps/machNotch/` layout.
* **Build command clarity**: Documented the current root-relative build command using `Apps/machNotch/machNotch.xcodeproj` and noted that plain root `xcodebuild` is not available until a root workspace/project/package exists.
* **Rename status**: Verified the active Xcode scheme/targets are `machNotch`, `MachNotchXPCHelper`, and `machNotchTests`; stale docs now point to the renamed scheme.
* **Build/test repair**: Fixed stale Xcode project paths for entitlements, Info.plists, preview assets, and moved source files so root-relative build and test commands pass again.
* **CI path cleanup**: Updated build, test, release, and Pages workflows to use the nested `Apps/machNotch/` project, configuration, and updater paths.

### 🎨 UI & Animation Polish

* **Wider, Cleaner Layout**: Increased notch width (`740pt` → `860pt`) for better spacing.
* **Unified Animations**: Rearchitected open/close animations for a smoother, interruptible, and more cohesive feel. Content and shell now animate together.
* **Refined Header**: Redesigned header with better padding, alignment, and a more compact tab selection view.
* **Improved Gestures**: Pan gestures for opening/closing the notch are now disabled when interacting with scrollable content, preventing accidental closures.
* **Consistent Padding**: Standardized padding and spacing across all notch components for a cleaner look.
* **Aggressive Content Absorption**: Content exit animation is now much more aggressive, creating a satisfying "absorbed into the notch" effect.

### 🐛 Bug Fixes & Refinements

* **UI State & Expansion Bugs**: Fixed a horizontal bounce after closing (due to stale phase checks), prevented the Battery expansion from stretching the Music plugin to 640px, and fixed the notch squishing when switching apps via `Cmd+Tab`.
* **Timeline Sync**: Mapped `duration` and `currentTime` from the active media controller to fix the timeline UI getting stuck at 0.
* **Shelf Drag and Drop**: Fixed an issue where dragging files out of the shelf would fail due to missing selection state context.
* **Accessibility Prompts**: Disabled automatic accessibility prompts on launch and settings load to prevent aggressive system popups.
* **Browser Media Controller**: Added support for browser extension media controls with SoundCloud metadata extraction.
* **External display fix**: Fixed notch not appearing on external (non-notch) displays when "Show on all displays" is enabled. The `.transient` collection behavior caused macOS to hide windows on non-notch screens.
* **Duplicate init call**: Removed duplicate `configureWindow()` call in `NotchSkyLightWindow` init.
* **Build regressions**: Fixed MusicService, SpotifyController, YouTubeMusicController, NowPlayingController, and PlaybackState regressions after efficiency refactor.
* **UI regressions**: Fixed clipping, shape integrity, and header alignment issues in open/closed notch states.
* **Centered layout**: Implemented centered 'hugging' layout with proper home tab visibility.
* **Project Structure**: Massive project file cleanup and reorganization. Moved dozens of files into a more logical structure, improving maintainability.
* **Animation Glitches**: Fixed a visual bug where the notch corners would not be rounded correctly during animations.
* **Gesture Conflicts**: Resolved gesture conflicts between the notch and scrollable content within plugins.
* **Removed Build Artifacts**: Deleted stale build output files from the repository.

### 🏗 Architecture Overhaul (Plugin System)

Completion of massive architectural refactoring. Monolithic singleton-based design → modular, plugin-first architecture.

* **Plugin Engine**: `PluginManager` + `NotchPlugin` protocol.
* **Everything is a Plugin**: All core features (Music, Battery, Calendar, Shelf, Weather, Webcam) migrated to standalone plugins in `Plugins/BuiltIn/`.
* **Service Container**: Replaced scattered singletons with unified `ServiceContainer` for DI.
* **Testability**: All services use protocols (`MusicServiceProtocol`, etc.), enabling mock injection.

### ✨ New Features

* **Teleprompter Pro**: Full-featured teleprompter with countdown timer, mic monitoring, hover-to-pause, keyboard shortcuts, AI text assist, control panel with speed/font/color.
* **Browser Extension**: Safari web extension for media control from the notch.
* **Habit Tracker Plugin**: Daily habit tracking with streaks, progress rings, persistent storage.
* **Pomodoro Plugin**: Focus timer with work/break intervals, session history, notch-integrated controls.
* **Display Surface Plugin**: Generic display arbitration for surfacing prioritized content.
* **Notifications Plugin**: Dedicated system notification handling.
* **Clipboard Plugin**: Clipboard history management from the notch.
* **AI Subsystem**: `AIManager` + `AIProvider` protocol for text generation.
* **Local API Server**: HTTP + WebSocket server for external integrations (`notchctl` CLI, browser extension). Auth middleware, rate limiting, plugin API routes.
* **App Intents & URL Scheme**: Siri Shortcuts integration + `machnotch://` URL scheme handler.
* **Protocol-Based Services**: Clean APIs enabling easy provider swaps.

### 🐛 Bug Fixes

* **XPC Helper**: Fixed IOServicePort leak in brightness check; broke retain cycle in connection invalidation handler.
* **Animation**: Fixed album art ghost on track change, smoother closing animation, shell-first open/close timeline.
* **Settings**: Reverted `bindableSettings` fatalError — SwiftUI resolves default before env modifier applies.
* **DI**: Added missing `@Environment(\.settings)` and Combine imports post-refactor.
* **Home View**: Default to home view on notch open instead of shelf.

### 🧹 Tech Debt & Improvements

* **Singleton Removal**: 300+ `.shared` sites removed. Views use `@Environment` or init injection.
* **Modern State Management**: Migrated to Swift 5.9 `@Observable` macro across all core models.
* **Decoupled Settings**: Split `DefaultsNotchSettings` into focused extensions (+Display, +HUD, +Music, +Plugins). No direct `Defaults[.]` outside settings files.
* **File Structure**: `Core/` for domain + coordination, `Plugins/` for features, `UI/` for view helpers.
* **Apple-quality animations**: Content reveal modifier, shadow easing, spring-tuned choreography.
* **Architecture gate CI**: Automated boundary violation checks.

### 🏛 SOLID & DDD Hardening

Comprehensive review and refactoring across 34+ files.

#### SRP Extractions

* **TeleprompterTimerManager**: Timer + mic monitor lifecycle extracted from `TeleprompterState`.
* **TeleprompterScrollEngine / ShortcutHandler / CountdownState**: Further SRP splits.
* **DisplayPrioritizer**: Display arbitration extracted from `PluginManager` into pure struct.
* **HeaderButton / HeaderActionButton**: Reusable components from `NotchHeader` (197→130 lines).
* **ContentView sub-views**: `notchBackground`, `glassOverlay`, `topEdgeLine` extracted.

#### DDD Improvements

* **PluginID enum**: 30+ stringly-typed identifiers → type-safe constants. Typos are compile errors.
* **SneakContentType.isHUD**: Moved to computed property on domain enum.
* **NotchServiceProvider**: Protocol for clean service resolution across plugin boundaries.

#### Clean Code

* **DisplaySurfaceState**: Private `ttlTask`, `[weak self]` capture, explicit `clear()`.
* **Named constants**: Magic numbers extracted across teleprompter state.
* **SpotifyController.setFavorite()**: LSP contract documented.

### ⚡ Performance

* **Phase 2 efficiency**: Isolated high-frequency progress updates into leaf reader views, event-driven geometry calculations replacing polling, XPC helper backoff strategy for reduced IPC overhead.
* **Background service backoff**: `BackgroundServiceRestartable` protocol pauses `BatteryService`/`BluetoothManager` polling when notch is closed.
* **NotchServiceProvider consolidation**: Single DI entry point replaces 8 individual service properties in `NotchViewModel`.
* **TimelineView gating**: Music controls switch to static layout when notch is closed (no 60fps background burn).
* **AVAudioRecorder lifecycle**: Mic hardware released immediately when teleprompter is paused.
* **AnyView elimination**: Plugin views use type-specific wrappers, restoring SwiftUI structural identity.
* **High-frequency reader isolation**: `elapsedTime` decoupled into leaf `ScrubberPlayheadView`.
* **GPU/CoreAnimation backoff**: Heavy blur/blend gated behind `!vm.phase.isTransitioning`.
* **Teleprompter off-main parsing**: Text section parsing offloaded to `Task.detached`.
* **Teleprompter closed view**: Wider layout, prominent X button, live speed slider (🐢↔🐇).
* **Background execution leaks**: Fixed rendering leaks in Teleprompter and Music plugins that burned CPU when notch was closed.
