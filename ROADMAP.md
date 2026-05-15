---
subtitle: What's being built, what's next, and what has shipped. For release notes see the [Changelog](changelog.html). Have a request? [Open an issue](https://github.com/larsboes/mach-mono/issues).
---

## ↑ In Development

### mach.brief [New App]

A minimal daily briefing widget for macOS and iOS. Calendar, tasks, weather — without noise. Phase 1 (App Group infrastructure, cross-app settings sync) and Phase 2 (vocabulary level system, onboarding picker) shipped in v1.3.0. iOS and full feature set in progress.

### Obsidian Vault Sync [Shelf]

Notes created in the Shelf plugin write to a configurable Obsidian vault folder as Markdown files, kept in sync on every save.

## ⌛ Planned

### Plugin SDK [Platform]

Public API and documentation so third-party developers can build and distribute their own notch plugins.

## 🚀 Launched

### v1.3.2 — 2026-05-16

- **Release pipeline unbroken**: Codesign now uses the correct `rules_apple` bundle path (`bazel-bin/Apps/machNotch/machNotch_archive-root/machNotch.app`) — root cause of the v1.2.0/v1.3.0/v1.3.1 release-build failures.
- **Release dry-run on every `main` push**: Packaging and codesign regressions caught pre-tag; release SHA matches build SHA; `cancel-in-progress: false` prevents split-state releases.
- **CI hardening**: Consolidated Bazel cache keys + Bazelisk binary cache; swift-format strict mode enabled with cleared baseline; tag pattern restricted to semver; arch-check SRC path corrected; CodeQL Swift moved to manual dispatch.
- **Teleprompter UI cleanup (closes #11)**: Final polish — `readingAreaHeightMultiplier` extraction and `ActionBarSecondaryStyle` relocation complete the cleanup tracked across prior sessions.
- **Note**: v1.3.1 was tagged on 2026-05-15 but its release build failed at codesign and produced no artifact. v1.3.2 supersedes it.

### v1.3.0 — 2026-05-10

- **PluginUIContext**: New environment type resolves DIP violations — plugin views no longer depend directly on `NotchViewModel`. All built-in plugin views migrated.
- **mach.brief Phase 1+2**: App Group infrastructure for cross-app settings sync; vocabulary level system with onboarding picker; word cache and offline fallback.
- **Bazel native build**: Full migration to native Bazel rules for machNotch and XPC service bundle. Taskfile.yml replaces Makefile.
- **macOS 26 compatibility**: Fixed XCTest async teardown crashes across multiple test files; switched CI to `macos-26` runner.
- **Fixes**: Bluetooth permission suppression; persistent TCC/accessibility sentinel; Calendar compact access prompt; stats `UInt64` underflow guard.

### v1.2.0 — 2026-05-03

First public release.

- **Plugin System**: `PluginManager` + `NotchPlugin` protocol. All core features (Music, Battery, Calendar, Shelf, Weather, Webcam) are standalone plugins.
- **Teleprompter Pro**: Countdown timer, mic monitoring, hover-to-pause, keyboard shortcuts, AI text refinement via Ollama.
- **Habit Tracker**: Daily tracking with streaks, progress rings, and persistent storage.
- **Pomodoro Timer**: Work/break intervals, session history, notch-integrated controls.
- **Browser Extension**: Safari extension for media controls and SoundCloud metadata.
- **Local API & notchctl**: HTTP + WebSocket server for external integrations; `machnotch://` URL scheme; App Intents for Siri Shortcuts.
- **AI Subsystem**: `AIManager` + `AIProvider` protocol with Ollama backend.
- **SOLID/DDD hardening**: 300+ singleton sites removed; `PluginID` enum; `DisplayPrioritizer`; `@Observable` migration.
- **Performance**: Background service backoff, `AnyView` elimination, GPU/CoreAnimation gating, high-frequency leaf view isolation.
