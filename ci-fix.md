# CI Fix Analysis — MusicPluginTests crash on macOS 26

## Status: FIXED (two-part fix applied)

## Symptom

Every CI run fails on `//Apps/machNotch:machNotchTests`.  
`MusicPluginTests` crashes with `Signal 6 / freed pointer was not the last allocation`.

## Root Cause

**macOS 26 / Xcode 26 beta bug in XCTest.**

Crash stack:
```
_swift_task_dealloc_specific
XCTSwiftErrorObservation._observeErrors(in:)
XCTFailableInvocation.invokeAsynchronousBlock
_shouldContinueAfterPerformingSetUpSequenceWithSelector
```

`_observeErrors(in:)` allocates a task-local slot and expects to free it LIFO. The crash
"freed pointer was not the last allocation" means `_observeErrors` is trying to free
its slot, but a NEWER allocation is still live on the same task's local-storage stack.

**Two-part mechanism:**

1. `testDisplayRequestWhenPlaying` body sets `mockMusicService.playbackState = PlaybackState(isPlaying: true)`.
   This fires the Combine publisher → `setupSubscriptions()` sink → an unstructured
   `Task { @MainActor }` (T1) is created and appended to `activeTasks`.

2. T1 was created with `Task { }` — it **inherits task-local values** from the enclosing
   async context (setUp's `_observeErrors` chain). This creates a linked reference from
   T1's task-local storage into setUp's task-local allocator.

3. Synchronous tearDown cancelled T1 but didn't AWAIT it. T1 was still pending on the
   MainActor queue when test 2's setUp started.

4. Test 2's setUp `_observeErrors` allocates a new slot. T1 is still alive and its
   inherited task-local reference points into a reused/corrupted portion of the
   task-local arena. When `_observeErrors` tries to free its slot (LIFO), the allocator
   finds the ordering wrong → CRASH.

## Why Task.detached Alone Didn't Fix It

Changing to `Task.detached` breaks task-local inheritance (T1 gets an isolated allocator).
This makes tearDown's `_observeErrors` safe. But T1 is still **pending on the MainActor
queue** when test 2 setUp starts. The crash still occurs during test 2's setUp
`_observeErrors` because T1, while detached, somehow still conflicts with the
allocator ordering when it runs concurrently during `_observeErrors`'s cleanup.

The correct fix requires BOTH parts:

## Fix Applied

### Part 1: Task.detached in setupSubscriptions()

`MusicPlugin.swift` — changed `Task { @MainActor [weak self] in }` to  
`Task.detached { @MainActor [weak self] in }`.

`Task.detached` creates a task with NO inherited task-locals. This makes T1's allocator
completely isolated from any XCTest `_observeErrors` chain. Teardown's `_observeErrors`
is no longer corrupted by T1's presence while T1 is pending.

### Part 2: async throws tearDown that awaits the detached task

`MusicPluginTests.swift` — changed back to `override func tearDown() async throws`
calling `await plugin.deactivate()`.

`deactivate()` cancels T1 and then **awaits T1's value** (`for task in tasks { _ = await task.value }`). This:
- Suspends tearDown (inside `_observeErrors`)
- Allows T1 to run on MainActor and return early (cancelled)
- T1 is now DONE before tearDown's `_observeErrors` tries to free its slot
- Since T1 is `Task.detached`, T1's completion has no effect on tearDown's allocator
- Test 2's setUp starts with NO pending T1 → no LIFO violation

### Part 3: NotchViewModel+Observers.swift Swift 6 warning fix

Added `self.hideOnClosed` inside `withAnimation` closure at line 38 — was missing
`self.` in a nested closure after `[weak self]` rebind, flagged as Swift 6 error.

## Previous Attempts That Did NOT Work

| Attempt | Why It Failed |
|---|---|
| Cancel + removeAll in synchronous tearDown | T1 cancelled but still pending — crash in test 2 setUp |
| `guard !Task.isCancelled` in task body | Doesn't prevent task from being queued, only affects body |
| `await task.value` in async tearDown (with Task { }) | T1 inherited setUp task-locals; tearDown's _observeErrors crashed while T1 was pending |
| `tearDown() async` (drop throws) | Compile error — base class is `async throws` |
| Synchronous `tearDown()` + `wait(for:)` | Deadlock — blocks MainActor which T1 needs to run |
| `Task.detached` alone with sync tearDown | T1 still pending on MainActor; crash still in test 2 setUp |

## Files Changed

- `MusicPlugin.swift`: `Task { @MainActor }` → `Task.detached { @MainActor }` with comment
- `MusicPluginTests.swift`: tearDown back to `async throws`, calls `await plugin.deactivate()`
- `NotchViewModel+Observers.swift`: explicit `self.hideOnClosed` in `withAnimation`
