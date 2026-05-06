# CI Fix Analysis — MusicPluginTests crash on macOS 26

## Status: FIXED

## Symptom

CI fails on `//Apps/machNotch:machNotchTests`.  
`MusicPluginTests` crashes with `Signal 6 / freed pointer was not the last allocation`.

## Root Cause

**macOS 26 / Xcode 26 beta bug in XCTest.**

Crash stack:
```
_swift_task_dealloc_specific
XCTSwiftErrorObservation._observeErrors(in:)
XCTFailableInvocation.invokeAsynchronousBlock
_shouldContinueAfterPerformingSetUpSequenceWithSelector  (or TearDown variant)
```

`_observeErrors(in:)` allocates a task-local slot (LIFO) and must free it last. The crash
"freed pointer was not the last allocation" fires when an unstructured Task that was
created during the test body is still pending on the MainActor when `_observeErrors`
tries to dealloc its slot — corrupting LIFO order.

**The trigger chain:**

1. `testDisplayRequestWhenPlaying` sets `mockMusicService.playbackState = PlaybackState(isPlaying: true)`.
2. Combine `didSet` fires `_playbackStateSubject.send(playbackState)`.
3. `setupSubscriptions()`'s sink creates an unstructured `Task { @MainActor }` (T1).
4. Synchronous tearDown cancels T1 but cannot await it — T1 remains pending on MainActor.
5. Any subsequent `_observeErrors` context (setUp or tearDown of next test) crashes when
   T1's presence corrupts the task-local deallocation order.

**What makes this bug unavoidable when using `async throws setUp/tearDown`:**
- Awaiting T1 in an async tearDown also crashes — tearDown's own `_observeErrors` is
  destabilized by T1 being pending when it enters.
- `Task.detached` (breaks task-local inheritance) alone is insufficient — T1 still
  disrupts `_observeErrors` allocator ordering while pending.
- This is a confirmed XCTest beta bug specific to macOS 26.3 (25D125).

## Fix Applied

**Root fix: Don't create T1 when there's nothing to do.**

`startAudioCapture()` already guards on `ambientVisualizerEnabled && mode == .realAudio`.
In tests, `MockNotchSettings.ambientVisualizerEnabled = false`, so the task body is a
no-op. Adding the same guard BEFORE task creation prevents T1 from being enqueued at all.

**`MusicPlugin.swift` — `setupSubscriptions()` Combine sink:**
```swift
self.eventBus?.emit(event)
guard let ms = self.mediaSettings, ms.ambientVisualizerEnabled else { return }
let t = Task.detached { @MainActor [weak self] in
    ...
}
self.activeTasks.append(t)
```

`Task.detached` is kept for production (correct actor isolation, no inherited task-locals).
The `ambientVisualizerEnabled` guard is correct behavior: don't drive audio capture when
the visualizer is disabled. Tests with the default mock (disabled) never create T1.

**`MusicPluginTests.swift` — tearDown remains synchronous:**
```swift
override func tearDown() {
    plugin.deactivate_cancelOnly()
    plugin = nil
    ...
}
```

Since no tasks are created in tests, synchronous tearDown is complete and correct.
No async `_observeErrors` wrapping needed.

**`NotchViewModel+Observers.swift` line 38:**  
Added `self.hideOnClosed` in nested `withAnimation` closure — was a Swift 6 error.

## All Attempts Made

| Attempt | Result |
|---|---|
| `guard !Task.isCancelled` in task body | No change |
| Cancel+removeAll in synchronous tearDown | Test 1 passes; tests 2-3 crash in setUp |
| `await task.value` in async tearDown (Task { }) | Crashes — T1 inherits task-locals from setUp's _observeErrors |
| Synchronous tearDown + wait(for:) | Deadlock — blocks MainActor |
| `Task.detached` alone with sync tearDown | Tests 2-3 still crash in setUp |
| async throws tearDown + await deactivate() + Task.detached | All tests crash in tearDown's own _observeErrors |
| **Guard on ambientVisualizerEnabled + sync tearDown** | **✓ No tasks created in tests → no crash** |

## Files Changed

- `MusicPlugin.swift`: guard task creation on `ambientVisualizerEnabled`; keep `Task.detached`
- `MusicPluginTests.swift`: synchronous tearDown calling `deactivate_cancelOnly()`
- `NotchViewModel+Observers.swift`: explicit `self.hideOnClosed` in `withAnimation`
