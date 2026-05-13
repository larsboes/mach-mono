# Plan: Bazel-first CI Migration

**Status:** In Progress
**Branch:** dev

---

## Context

Current CI is 100% Xcode-based (`xcodebuild` across all workflows). Bazel builds already work locally (`bazel build //Apps/machNotch:machNotch`, `//Apps/machBrief:machBrief`, `bazel test //Packages/MachBriefKit:MachBriefKitTests`). Goal: make Bazel the sole CI build system.

**Existing workflows:**

| File | Role | Current toolchain |
|---|---|---|
| `cicd.yml` | PR/push build + test | `xcodebuild` (workspace) |
| `build_reusable.yml` | Signed build, DMG, artifact | `xcodebuild archive/export` |
| `release.yml` | Tag → release: appcast + gh release | Xcode-signed |
| `manual_build.yml` | Manual dispatch | Xcode-signed |
| `arch-check.sh` | Architecture conventions (Ubuntu) | Bash/grep only — unchanged |

**Known gaps before this plan:**
- No `.bazelversion` file — bazelisk unpinned
- No `swift_test` target for machNotch's 53 unit tests (Xcode-only)
- `minimum_os_version = "15.0"` in machNotch BUILD.bazel — stale (should be 26.0)
- `Apps/machNotch/CLAUDE.md` build commands still reference xcodebuild

---

## Phase 1 — Fast CI (`cicd.yml`) `[COMPLETE]`

**Goal:** Every push/PR validates via Bazel. Xcode gone from the hot path.

- [x] `.bazelversion` pins Bazel 7.6.1 (latest stable; "Bazel 9" in original plan was aspirational — no ADR found)
- [x] `--config=ci` block in `.bazelrc` with all CI flags
- [x] `cicd.yml` uses `bazelisk build/test --config=ci` with dual-layer Actions cache
- [x] `minimum_os_version = "26.0"` in `Apps/machNotch/BUILD.bazel`
- [x] `Apps/machNotch/CLAUDE.md` build/test commands use `bazelisk`

**Note:** machNotch's 53 unit tests do not yet run in Bazel CI — no Bazel test target exists. Addressed in Phase 2.

---

## Phase 2 — machNotch Bazel test target `[medium complexity]`

**Goal:** The 53 machNotch unit tests run in CI under Bazel.

Tests today live in Xcode only. They are pure unit tests (NotchStateMachineTests, NotchHoverControllerTests, etc.) that should compile standalone with mocked services.

- [x] Audit test files for AppKit/UI dependencies vs pure logic
- [x] Add `swift_test` target to `Apps/machNotch/BUILD.bazel` with dep on `machNotch_Lib`
- [x] Wire into `cicd.yml` test job: add `//Apps/machNotch:machNotchTests`
- [x] Fix any test files that don't compile under Bazel (hidden implicit deps surfaced by strict module isolation)

**Risk:** Test files may rely on Xcode implicit linking. Phase 2 is isolated — cannot break Phase 1.

---

## Phase 3 — Signed release pipeline (`build_reusable.yml`) `[complex]`

**Goal:** Release DMGs produced by Bazel, not `xcodebuild archive`.

**Strategy:** Bazel builds the `.app`, post-build scripts handle signing + DMG. Standard pattern for Bazel + macOS — clean separation between compilation (Bazel) and distribution signing (codesign).

- [x] **Version injection** — replace `sed project.pbxproj` with Bazel workspace stamping:
  - Add `tools/workspace_status.sh` emitting `STABLE_VERSION` and `STABLE_BUILD_NUMBER` from env vars
  - Add `stamp = True` to `macos_application` in `Apps/machNotch/BUILD.bazel`
  - Patch `bazel_info.plist` to use `{STABLE_VERSION}` / `{STABLE_BUILD_NUMBER}` (already wired as second infoplist)

- [x] **Compilation step** — replace `xcodebuild clean archive` with:
  ```
  bazelisk build //Apps/machNotch:machNotch \
    --stamp \
    --workspace_status_command="tools/workspace_status.sh"
  ```

- [x] **Signing step** — sign the Bazel output `.app`:
  ```bash
  APP_PATH="bazel-bin/Apps/machNotch/machNotch.app"
  codesign --deep --force --sign "$CODE_SIGN_IDENTITY" "$APP_PATH"
  ```
  Certificate installation block (`security import`) stays identical.

- [x] **DMG step** — `create_dmg.sh` takes a `.app` path — no changes, point at `bazel-bin/Apps/machNotch/machNotch.app`

- [x] **Remove** from `build_reusable.yml`: `Resolve Swift packages`, `Select Xcode`, `xcodebuild archive`, `xcodebuild export`

- [x] `release.yml` publish job — unchanged (operates on DMG artifact)

**What stays:** certificate import, DMG creation, Sparkle appcast generation, GitHub release creation.

---

## Sequencing

```
Phase 1  →  Phase 2  →  Phase 3
(1-2h)      (2-4h)      (4-6h)
```

Phase 1 and 2 are independent of release infra — safe to merge separately.
Phase 3 requires Phase 1 (shared `.bazelrc` CI config).

---

## Progress

- [x] Phase 1 complete
- [x] Phase 2 complete
- [x] Phase 3 complete

---

## GitHub Pages Site (`Apps/machNotch/updater/`)

The public site at `larsboes.github.io/mach-mono`. Served from `Apps/machNotch/updater/` via `static.yml`. Currently a single `index.html` with no download button, no screenshots, no subpages.

### Phase 1 — Homepage improvements `[COMPLETE]`
- [x] Download CTA button linking to latest release
- [x] Plugin grid showcasing all built-in plugins
- [x] Screenshots section using existing docs/images
- [x] Nav bar linking to changelog and guide

### Phase 2 — Changelog page (`/changelog.html`) `[COMPLETE]`
- [x] Styled changelog matching site aesthetic
- [x] Shows what's in the upcoming release + version history structure

### Phase 3 — Getting started page (`/guide.html`) `[COMPLETE]`
- [x] Install steps (download → drag → permissions → hover)
- [x] Permissions guide (Accessibility required; Calendar, Camera, Mic optional)
- [x] Nav to changelog and back to home

---

## Planned Features

Features scoped and agreed but not yet scheduled.

### Notes — Obsidian Integration `[COMPLETE]`

Reuse the `ObsidianSink` pattern from `MachBriefKit`. When a note is created or updated, write a markdown file to a configurable vault path. Needs:
- [x] `obsidianVaultPath: String?` setting in `NotesManager` (persisted to UserDefaults)
- [x] Write/update `.md` file on `addNote` / `updateNote`
- [x] Settings UI toggle + path picker in the notes settings view

### Notes — Buggy State Investigation

- [x] Lars reports an intermittent weird visual state in the notes tab. *Fixed: Traced to `WindowCoordinator` squishing the notch on `cmd+tab` and `NotchStateMachine` forcing Music layout during Battery expansion events.*
- [x] Notch randomly expands horizontally to 640px. *Fixed: `BatteryService.notifyImportantChange` was firing the battery expanding view on every 1% level drop (not just plug/unplug). Added `powerStatusChanged` parameter — now the `showPowerStatusNotifications` branch only fires when `pluggedInChanged || chargingChanged`.*

---

## Architecture Audit Findings (2026-05-07)

Findings from a parallel-agent audit of the full `Apps/machNotch` tree. Ranked by **impact × effort**. Items 1–9 are deletions/one-liners (~1 day total). Items 10+ require test coverage first.

### Quick wins — do first (deletions + surgical fixes)

- [x] **Delete `NotchWindow.swift`** — confirmed dead code (never instantiated; `NotchSkyLightWindow` is the active window class). 75 lines of duplicated panel setup.
- [x] **Fix `WindowCoordinator` display-reconfiguration crash** — `WindowCoordinator.swift:34–46` uses `Unmanaged.takeUnretainedValue()` inside `CGDisplayRegisterReconfigurationCallback`. Dangling pointer if coordinator deallocates during hot-plug. Swap to `NSApplication.didChangeScreenParametersNotification` or use retained Unmanaged correctly.
- [x] **Fix `PluginManager` leaking `ServiceContainer`** — `PluginManager.swift:28` declares `let services: ServiceContainer` (concrete). Change to `let services: any NotchServiceProvider`. One-line fix; surfaces latent leaks.
- [x] **Retire `PermissionStateStore.shared`** — `PermissionStateStore.swift:8–9`. Only 3 call sites. Route through `AppObjectGraph`/`PluginContext`, mark `.shared` internal.
- [x] **Add `MEMORY/WORK/` to `.gitignore`** — 8 untracked PRD dirs cluttering `git status`. One line: `MEMORY/WORK/*/`.
- [x] **Delete `test.swift`** at repo root — orphan 12-line debug file, compiles into nothing.
- [x] **Delete `components/TestView.swift`** — 88-line FluidSlider prototype, not imported anywhere. Verify with `grep -r FluidSlider` first.
- [x] **Delete `Core/ScreenSelectionService.swift`** — empty file with a "retired" comment.
- [x] **Replace `print()` with `Logger` in `MediaControllers/`** — 13 raw `print()` calls; `utils/Logger.swift` already exists.

### Architectural (needs characterization tests first)

- [x] **Consolidate state determination** — state currently triplicated across `NotchViewModel`, `NotchStateInput` (rebuilt in `ContentView.updateStateMachine()`), and `NotchStateMachine.computeDisplayState()`. Any new input must be wired in all three. Migrate `NotchStateMachine` to consume `@Observable` objects directly via `withObservationTracking`.
- [x] **Fix `NotchViewModel ↔ NotchPhaseCoordinator` bidirectional contract** — `NotchPhaseDelegate` exposes `startHoverHeartbeat`/`stopHoverHeartbeat` (`NotchPhaseCoordinator.swift:31–33`) — heartbeat is not VM concern. Strip from delegate; let `NotchHoverController` manage its own heartbeat.
- [x] **Replace 44 `DispatchQueue.main.async` calls** — codebase is `@MainActor`-annotated; most dispatches are noise. Convert to direct calls or `Task { @MainActor in … }` where coming from a background callback.
- [x] **Migrate `NowPlayingController` off Combine** — `NowPlayingController.swift:12–47` is both `@Observable` and publishes via `CurrentValueSubject`/`PassthroughSubject`. Migration debt — remove the subjects, convert `.sink` callers to `withObservationTracking` / `AsyncStream`.
- [x] **Fix `NotchSkyLightWindow` Combine leak** — `observers: Set<AnyCancellable>` populated at lines 90–106, never cleared in `deinit` or `orderOut`. Add `deinit { observers.removeAll() }`.
- [x] **Multi-display UUID single source of truth** — UUID state lives in `WindowCoordinator.swift:18` (keyed dict), `WindowCoordinator+MultiDisplay.swift:13` (rebuilds per call), and `NSScreenUUIDCache.shared` — three independent listeners for `NSScreen` changes with no handshake. Consolidate into a `ScreenDisplayRegistry` service.
- [x] **`NSScreen.main` nil assumption** — `WindowCoordinator+MultiDisplay.swift:57` assumes `NSScreen.main` is non-nil; silently fails to place window on headless/boot edge cases. Guard with `?? NSScreen.screens.first`.
- [x] **Coordinator clarity rule** — `NotchPhaseCoordinator.phase` is now `private(set)`. Only internal open/close/scrub methods mutate it.
- [x] **Extract stub services into `CommonTestStubs.swift`** — all `Stub*` types, `TestNotchServiceProvider`, `MockMusicService`, and `MockAppState` moved out of `MusicPluginTests.swift` into shared `CommonTestStubs.swift`. Future test files can reuse without redefining.
- [x] **`HabitTrackerPlugin`/`PomodoroPlugin` direct coordinator coupling** — migrated to `@Environment(PluginUIContext.self)`; `isScrollableViewPresented` added to `PluginUIContext`.
- [x] **`PluginEventBus` untyped escape hatch** — removed `emit(_:from:data:)` overload and `data` field from `GenericPluginEvent`. Callers use concrete event types.
- [x] **`MockNotchSettings` missing `@MainActor`** — added `@MainActor` annotation.
