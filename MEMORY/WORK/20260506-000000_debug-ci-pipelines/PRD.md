---
task: check newest CI pipelines and debug failures
slug: 20260506-000000_debug-ci-pipelines
effort: standard
phase: execute
progress: 0/10
mode: interactive
started: 2026-05-06T00:00:00Z
updated: 2026-05-06T00:02:00Z
---

## Context

Every recent CI run on `dev` fails on `//Apps/machNotch:machNotchTests`. Build and Architecture Check jobs pass. The single failing test target crashes on `MusicPluginTests.testDisplayRequestWhenPlaying`.

**Root cause:** `testDisplayRequestWhenPlaying` (sync test) sets `mockMusicService.playbackState = PlaybackState(isPlaying: true)`. This fires the Combine sink in `setupSubscriptions()`, which creates `Task { @MainActor [weak self] in ... }` enqueued on the MainActor executor. `deactivate()` calls `activeTasks.forEach { $0.cancel() }` then `activeTasks.removeAll()` — drops the reference but the task is still pending in the executor queue. When XCTest's teardown machinery calls `XCTSwiftErrorObservation._observeErrors(in:)` while a cancelled-but-not-yet-run task is pending, Swift Concurrency's `_swift_task_dealloc_specific` detects the task-local storage deallocation order violation and aborts.

**Fix:** 
1. In `deactivate()`: cancel subscriptions FIRST (prevents new tasks), then capture+clear `activeTasks`, cancel all, and `await` each to completion before proceeding.
2. In `setupSubscriptions()` task body: add `guard !Task.isCancelled` so cancelled tasks exit immediately when awaited.

**Files:** `Apps/machNotch/machNotch/Plugins/BuiltIn/MusicPlugin/MusicPlugin.swift`

### Risks

- Awaiting tasks in `deactivate()` requires task bodies to handle cancellation, otherwise deactivate hangs.
- `startAudioCapture()` doesn't check `Task.isCancelled` — but in tests `ambientVisualizerEnabled = false` so it returns immediately anyway.
- Order matters: subscriptions must be cancelled before awaiting tasks.

## Criteria

- [ ] ISC-1: `MachBriefKitTests` passes without regression
- [ ] ISC-2: `machNotchTests` test binary completes without SIGABRT
- [ ] ISC-3: `MusicPluginTests.testDisplayRequestWhenPlaying` passes
- [ ] ISC-4: `MusicPluginTests.testNoDisplayRequestWhenIdleAndPaused` passes
- [ ] ISC-5: `MusicPluginTests.testNowPlayingInfoReflectsServiceState` passes
- [x] ISC-6: `deactivate()` cancels Combine subscriptions before awaiting tasks
- [x] ISC-7: `deactivate()` awaits every active task before clearing and returning
- [x] ISC-8: Task body in `setupSubscriptions` checks `Task.isCancelled` first
- [x] ISC-9: No new tasks can be added to `activeTasks` during deactivate teardown
- [ ] ISC-10: Build job (`//Apps/machNotch:machNotch`) still passes

## Decisions

## Verification
