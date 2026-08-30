---
subtitle: What's being built, what's next, and what has shipped. For release notes see the [Changelog](changelog.html). Have a request? [Open an issue](https://github.com/larsboes/mach-mono/issues).
---

## Execution stack (issue-driven)

- **Tracking model:** Priority and milestone state are driven from GitHub issues + project board, not in-repo PLAN/PRD files.
- **Current order:**
  1. machHealth: execute the phased build (#51)
  2. machSound: close M3.5 parity and the M4/M5/M6 integration plan (#48, #49)
- **Note:** #48 and #49 scope themselves by section number in `Plans/PLAN-machSound.md`,
  which was deleted on 2026-08-01. They need rewriting against the tree before they
  are workable.

## ↑ In Development

### mach.brief [New App]

A minimal daily briefing widget for macOS and iOS. Calendar, tasks, weather — without noise. Phase 1 (App Group infrastructure, cross-app settings sync) and Phase 2 (vocabulary level system, onboarding picker) shipped in v1.3.0. iOS and full feature set in progress.

### machSound DSP [Audio]

Close the remaining phase-4 parity gaps against the reference engine, then land the M4/M5/M6 integration plan.

## ⌛ Planned

### machHealth Exporter [New App]

Small iOS exporter for HealthKit-derived signals that machSound can consume on
macOS through a versioned LAN JSON contract.

## 🚀 Launched

### SystemStats GPU Ring — 2026-08-30

GPU utilization joins CPU, memory, disk and network. It is read from the busiest IOAccelerator's `PerformanceStatistics`, tolerating the key rename across generations, and a machine that publishes neither spelling reports no GPU rather than a false zero. Sampling moved into `SystemStatsSampler`, which returns nil rather than zero when a source has no answer yet, so a failed syscall no longer renders as "idle".

### Semantic Shelf Search, Working — 2026-08-30

`SQLiteVecIndex.upsert` inserted against a filtered query, which is not a valid INSERT target, so every insert threw and the shelf fell back to substring matching without saying so. With that fixed, queries are answered from an in-memory mirror of L2-normalized vectors: top-5 over 10k items went from 1239 ms to 12 ms. Re-indexing is incremental — items carry a hash of the text they were indexed from, so an unchanged shelf costs no embedding calls.

### Plugin SDK — 2026-08-30

The public plugin API is frozen and published. `NotchPluginCore` is the SDK product: it holds the protocol, the context and the descriptor, and depends on no plugin. Capability narrowing is now enforced rather than advisory — each service accessor returns a facade conforming to one sub-protocol, so a plugin cannot cast back up to reach services it never declared, and an external plugin receives only the groups its descriptor lists. [`examples/HelloPlugin`](https://github.com/larsboes/mach-mono/tree/main/examples/HelloPlugin) builds and tests with plain `swift build`, which is the standing check that the SDK stays consumable without Tuist.

### machNotch Architecture Hardening — 2026-06-13

The June 2026 hardening pass shipped: app `@main` shim split, per-plugin build
targets, app-facing plugin facade bridges, strict descriptor-based on-demand
plugin loading, external descriptor discovery prep, and default AudioKit-free
builds with Soundscape behind an explicit opt-in target — built then with a
Bazel label, now with `task build:soundscape` against the `machNotchWithSoundscape`
target in [`Apps/machNotch/Project.swift`](Apps/machNotch/Project.swift).

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

## 🚀 Build System

Tuist generates the Xcode projects from `Project.swift` manifests. Xcode is a
first-class build and debug entrypoint again; `task` wraps the canonical
commands. See [`Architecture.md`](Architecture.md) and [`repo.yaml`](repo.yaml).

### Migrated off Bazel — 2026-08-30

Bazel was replaced by Tuist. It was priced for a scale this repo does not have:
one developer, two apps, ~100k lines. What it cost, all of it visible in the
repo it left behind — an 83 KB lockfile, a pinned `rules_apple` patch for the
xctestrun template, `rules_swift_package_manager` as a bridge to consume SwiftPM
packages, three cache steps duplicated across every CI job, and an Xcode
workspace demoted to "navigation only".

Carried over: the plugin-per-module boundary, the Soundscape opt-in split, and
the AudioKit-free guarantee — now checked with `task verify:no-soundscape`,
which inspects the built binary instead of the build graph.

Found during the migration, all pre-existing:

- The XPC helper's bundle id never matched `XPCHelperClient.serviceName`, so the
  privileged helper could not connect in a Bazel build. Restored to the value
  the committed Xcode project used.
- `AudioKit` and `SoundpipeAudioKit` were declared dependencies with no
  first-party imports. Dropped.
- `PomodoroTimerTests` read and wrote the user's real
  `~/Library/Application Support/machNotch/pomodoro.json`. Bazel's sandbox hid
  it; the store is now injectable and tests use a temp file.
