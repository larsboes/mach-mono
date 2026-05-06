# CI Fix Analysis — MusicPluginTests crash on macOS 26

## Symptom

Every CI run fails on `//Apps/machNotch:machNotchTests`.  
`MusicPluginTests` crashes with `Signal 6 / freed pointer was not the last allocation`.

## Root Cause

**macOS 26 / Xcode 26 beta bug in XCTest.**

`XCTSwiftErrorObservation._observeErrors(in:)` is XCTest's internal mechanism  
that wraps `async throws` setUp/tearDown with task-local error observation.  
On macOS 26 beta, this function's task-local storage deallocation (`_swift_task_dealloc_specific`)  
fires in the wrong order when:
1. The test class has `@MainActor` at the class level
2. `tearDown` is `async throws`
3. An unstructured `Task { @MainActor }` was enqueued during the synchronous test body  
   (specifically, when `mockMusicService.playbackState` is set → Combine sink → Task appended to `activeTasks`)

Crash stack (abbreviated):
```
_swift_task_dealloc_specific                          ← wrong dealloc order
XCTSwiftErrorObservation._observeErrors(in:)
XCTFailableInvocation.invokeAsynchronousBlock
_performTearDownSequenceWithSelector
```

## What Was Tried

| Attempt | Result |
|---|---|
| Cancel + removeAll in deactivate | No change — crash still in tearDown |
| `guard !Task.isCancelled` in task body | No change — tasks aren't the root cause |
| Cancel subscriptions before tasks in deactivate | No change |
| Await tasks (`for task in tasks { _ = await task.value }`) | No change |
| `tearDown() async` (drop throws) | Compile error — base class is `async throws` |
| Synchronous `tearDown()` + `wait(for:)` | Deadlock + AppKit assertion on MainActor |
| Synchronous `tearDown()` + `deactivate_cancelOnly()` | test 1 passes, test 2 still crashes |

## Current State (partial fix)

`testDisplayRequestWhenPlaying` now **passes** with the synchronous tearDown.  
`testNoDisplayRequestWhenIdleAndPaused` still crashes — the crash moved into setUp  
for the second test, suggesting the macOS 26 bug also affects `async throws setUp`  
under certain conditions (possibly related to the pending Task from test 1's  
`deactivate_cancelOnly()` not awaiting completion before setUp runs).

## Changes Made So Far

**`MusicPlugin.swift`**
- Added `deactivate_cancelOnly()` — synchronous cancel of subscriptions + tasks
- `deactivate()` now cancels subscriptions first, then cancels+awaits tasks
- Task body in `setupSubscriptions` checks `!Task.isCancelled` first

**`MusicPluginTests.swift`**
- `tearDown() async throws` → `tearDown()` (synchronous) calling `deactivate_cancelOnly()`

## What Still Needs Fixing

The `async throws setUp` path likely has the same macOS 26 XCTest bug.  
Options to investigate:
1. Remove `@MainActor` from `MusicPluginTests` class level and use `nonisolated(unsafe)` properties  
   — this changes how XCTest schedules setUp/tearDown and may avoid `_observeErrors`
2. Move test activation into a `withActivatedPlugin { }` helper so setUp/tearDown are both synchronous
3. Wait for a macOS 26 / Xcode 26 release that fixes the XCTest bug

The `deactivate()` changes (task ordering + cancellation check) are correct  
and should stay regardless of the test fix.
