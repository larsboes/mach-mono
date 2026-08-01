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

### machHealth Exporter [New App]

Small iOS exporter for HealthKit-derived signals that machSound can consume on
macOS through a versioned LAN JSON contract.

## 🚀 Launched

### machNotch Architecture Hardening — 2026-06-13

The June 2026 hardening pass shipped: app `@main` shim split, per-plugin Bazel
targets, app-facing plugin facade bridges, strict descriptor-based on-demand
plugin loading, external descriptor discovery prep, and default AudioKit-free
builds with Soundscape behind `//Apps/machNotch:machNotchWithSoundscape`.

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
- **Teleprompter Pro**: Countdown timer, mic monitoring, hover-to-pause, keyboard shortcuts, AI text refinement.
- **Habit Tracker**: Daily tracking with streaks, progress rings, and persistent storage.
- **Pomodoro Timer**: Work/break intervals, session history, notch-integrated controls.
- **Browser Extension**: Safari extension for media controls and SoundCloud metadata.
- **Local API & notchctl**: HTTP + WebSocket server for external integrations; `machnotch://` URL scheme; App Intents for Siri Shortcuts.
- **AI Subsystem**: Foundation Models by default with oMLX as an advanced localhost provider.
- **SOLID/DDD hardening**: 300+ singleton sites removed; `PluginID` enum; `DisplayPrioritizer`; `@Observable` migration.
- **Performance**: Background service backoff, `AnyView` elimination, GPU/CoreAnimation gating, high-frequency leaf view isolation.

---

## ↑ Bazel Monorepo Roadmap

Bazel (Bzlmod) is the primary build and orchestration layer for this monorepo. Xcode remains the IDE entrypoint; all builds go through `bazel build`.

### Phase 1: macOS Foundation

1. [x] **Install Bazel:** Used `bazelisk`.
2. [x] **Initialize Monorepo:** Setup `MODULE.bazel` with `rules_apple`, `rules_swift`.
3. [x] **Create Shared Core:** Migrated `Packages/` to Bazel `swift_library` targets.
4. [x] **Create macOS App:** Defined `macos_application` target in `Apps/machNotch/BUILD.bazel`.
5. [x] **Native Builds:** Resolved `apple_crosstool_top` toolchain issue — upgraded to `rules_apple 4.5.3`, `rules_swift 3.6.1`, `apple_support 2.5.4`.

### Phase 2: machBrief Integration

1. [x] **machBrief BUILD.bazel:** Defined `macos_application` + `macos_extension` targets.
2. [x] **MachBriefKit Bazel Tests:** Added `swift_test` coverage at `//Packages/MachBriefKit:MachBriefKitTests`.
3. [x] **XPC Service Bundling:** `MachNotchXPCHelper` is wired as an embedded `macos_xpc_service` via `xpc_services` in `Apps/machNotch/BUILD.bazel`.
4. [x] **Code Signing:** Local builds sign via `task run` (Apple Development cert); CI signs Bazel output via `codesign --deep` in `build_reusable.yml`.

### Phase 3: CI/CD

- [x] Replace Xcode-based CI with `bazel build` + `bazel test` in GitHub Actions (cicd.yml fully on `bazelisk --config=ci`).
- [x] Cache remote build results — `~/.cache/bazel-repos` + `~/.cache/bazel` keyed on `MODULE.bazel` / `Package.resolved` / BUILD files.
- [x] Add dependency security signal — PR dependency review enforces high+ vulnerability and GPL/MPL-family license policy, while main/manual runs export the GitHub dependency graph SBOM artifact.

### Phase 4: iOS / Cross-Platform

- [ ] Create `ios_application` targets reusing `Packages/` modules.
- [ ] Future: Integrate `rules_android` and `rules_kotlin` for machBrief Android.
