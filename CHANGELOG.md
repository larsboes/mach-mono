# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### 🎨 UI & Animation Polish
*   **Wider, Cleaner Layout**: Increased notch width (`740pt` → `860pt`) for better spacing.
*   **Unified Animations**: Rearchitected open/close animations for a smoother, interruptible, and more cohesive feel. Content and shell now animate together.
*   **Refined Header**: Redesigned header with better padding, alignment, and a more compact tab selection view.
*   **Improved Gestures**: Pan gestures for opening/closing the notch are now disabled when interacting with scrollable content, preventing accidental closures.
*   **Consistent Padding**: Standardized padding and spacing across all notch components for a cleaner look.
*   **Aggressive Content Absorption**: Content exit animation is now much more aggressive, creating a satisfying "absorbed into the notch" effect.

### 🐛 Bug Fixes & Refinements
*   **External display fix**: Fixed notch not appearing on external (non-notch) displays when "Show on all displays" is enabled. The `.transient` collection behavior caused macOS to hide windows on non-notch screens.
*   **Duplicate init call**: Removed duplicate `configureWindow()` call in `BoringNotchSkyLightWindow` init.
*   **Build regressions**: Fixed MusicService, SpotifyController, YouTubeMusicController, NowPlayingController, and PlaybackState regressions after efficiency refactor.
*   **UI regressions**: Fixed clipping, shape integrity, and header alignment issues in open/closed notch states.
*   **Centered layout**: Implemented centered 'hugging' layout with proper home tab visibility.
*   **Project Structure**: Massive project file cleanup and reorganization. Moved dozens of files into a more logical structure, improving maintainability.
*   **Animation Glitches**: Fixed a visual bug where the notch corners would not be rounded correctly during animations.
*   **Gesture Conflicts**: Resolved gesture conflicts between the notch and scrollable content within plugins.
*   **Removed Build Artifacts**: Deleted stale build output files from the repository.

### 🏗 Architecture Overhaul (Plugin System)
Completion of massive architectural refactoring ("Phase 5"). Monolithic singleton-based design → modular, plugin-first architecture.

*   **Plugin Engine**: `PluginManager` + `NotchPlugin` protocol.
*   **Everything is a Plugin**: All core features (Music, Battery, Calendar, Shelf, Weather, Webcam) migrated to standalone plugins in `Plugins/BuiltIn/`.
*   **Service Container**: Replaced scattered singletons with unified `ServiceContainer` for DI.
*   **Testability**: All services use protocols (`MusicServiceProtocol`, etc.), enabling mock injection.

### ✨ New Features
*   **Teleprompter Pro**: Full-featured teleprompter with countdown timer, mic monitoring, hover-to-pause, keyboard shortcuts, AI text assist (refine/summarize/draft via Ollama), control panel with speed/font/color.
*   **Browser Extension**: Safari web extension for media control from the notch.
*   **Habit Tracker Plugin**: Daily habit tracking with streaks, progress rings, persistent storage.
*   **Pomodoro Plugin**: Focus timer with work/break intervals, session history, notch-integrated controls.
*   **Display Surface Plugin**: Generic display arbitration for surfacing prioritized content.
*   **Notifications Plugin**: Dedicated system notification handling.
*   **Clipboard Plugin**: Clipboard history management from the notch.
*   **AI Subsystem**: `AIManager` + `AIProvider` protocol with Ollama backend for text generation.
*   **Local API Server**: HTTP + WebSocket server for external integrations (`notchctl` CLI, browser extension). Auth middleware, rate limiting, plugin API routes.
*   **App Intents & URL Scheme**: Siri Shortcuts integration + `boringnotch://` URL scheme handler.
*   **Protocol-Based Services**: Clean APIs enabling easy provider swaps.

### 🐛 Bug Fixes
*   **XPC Helper**: Fixed IOServicePort leak in brightness check; broke retain cycle in connection invalidation handler.
*   **Animation**: Fixed album art ghost on track change, smoother closing animation, shell-first open/close timeline.
*   **Settings**: Reverted `bindableSettings` fatalError — SwiftUI resolves default before env modifier applies.
*   **DI**: Added missing `@Environment(\.settings)` and Combine imports post-refactor.
*   **Home View**: Default to home view on notch open instead of shelf.

### 🧹 Tech Debt & Improvements
*   **Singleton Removal**: 300+ `.shared` sites removed. Views use `@Environment` or init injection.
*   **Modern State Management**: Migrated to Swift 5.9 `@Observable` macro across all core models.
*   **Decoupled Settings**: Split `DefaultsNotchSettings` into focused extensions (+Display, +HUD, +Music, +Plugins). No direct `Defaults[.]` outside settings files.
*   **File Structure**: `Core/` for domain + coordination, `Plugins/` for features, `UI/` for view helpers.
*   **Apple-quality animations**: Content reveal modifier, shadow easing, spring-tuned choreography.
*   **Architecture gate CI**: Automated boundary violation checks.

### 🏛 SOLID & DDD Hardening
Comprehensive review and refactoring across 34+ files.

#### SRP Extractions
*   **TeleprompterTimerManager**: Timer + mic monitor lifecycle extracted from `TeleprompterState`.
*   **TeleprompterScrollEngine / ShortcutHandler / CountdownState**: Further SRP splits.
*   **DisplayPrioritizer**: Display arbitration extracted from `PluginManager` into pure struct.
*   **HeaderButton / HeaderActionButton**: Reusable components from `BoringHeader` (197→130 lines).
*   **ContentView sub-views**: `notchBackground`, `glassOverlay`, `topEdgeLine` extracted.

#### DDD Improvements
*   **PluginID enum**: 30+ stringly-typed identifiers → type-safe constants. Typos are compile errors.
*   **SneakContentType.isHUD**: Moved to computed property on domain enum.
*   **NotchServiceProvider**: Protocol for clean service resolution across plugin boundaries.

#### Clean Code
*   **DisplaySurfaceState**: Private `ttlTask`, `[weak self]` capture, explicit `clear()`.
*   **Named constants**: Magic numbers extracted across teleprompter state.
*   **SpotifyController.setFavorite()**: LSP contract documented.

### ⚡ Performance
*   **Phase 2 efficiency**: Isolated high-frequency progress updates into leaf reader views, event-driven geometry calculations replacing polling, XPC helper backoff strategy for reduced IPC overhead.
*   **Background service backoff**: `BackgroundServiceRestartable` protocol pauses `BatteryService`/`BluetoothManager` polling when notch is closed.
*   **NotchServiceProvider consolidation**: Single DI entry point replaces 8 individual service properties in `BoringViewModel`.
*   **TimelineView gating**: Music controls switch to static layout when notch is closed (no 60fps background burn).
*   **AVAudioRecorder lifecycle**: Mic hardware released immediately when teleprompter is paused.
*   **AnyView elimination**: Plugin views use type-specific wrappers, restoring SwiftUI structural identity.
*   **High-frequency reader isolation**: `elapsedTime` decoupled into leaf `ScrubberPlayheadView`.
*   **GPU/CoreAnimation backoff**: Heavy blur/blend gated behind `!vm.phase.isTransitioning`.
*   **Teleprompter off-main parsing**: Text section parsing offloaded to `Task.detached`.
*   **Teleprompter closed view**: Wider layout, prominent X button, live speed slider (🐢↔🐇).
*   **Background execution leaks**: Fixed rendering leaks in Teleprompter and Music plugins that burned CPU when notch was closed.
