# CI Fix Analysis — MusicPluginTests crash on macOS 26

## Status: FIXED

## Symptom

CI fails on `//Apps/machNotch:machNotchTests`.  
`MusicPluginTests` crashes with `Signal 6 / freed pointer was not the last allocation`.

## Root Cause

**macOS 26 / Xcode 26 beta bug in XCTest (macOS 26.3 build 25D125).**

Crash stack:
```
_swift_task_dealloc_specific          ← LIFO violation in task-local allocator
XCTSwiftErrorObservation._observeErrors(in:)
XCTFailableInvocation.invokeWithAsynchronousWait
invokeInvocation:withTestMethodConvention  (or _shouldContinueAfterPerformingSetUpSequenceWithSelector)
```

`_observeErrors(in:)` wraps every `async throws` function (setUp, tearDown, test methods)
with task-local error observation. It allocates a slot and expects to free it LIFO.

**The actual culprit: `QuickShareService.init()`**

`TestNotchServiceProvider.init()` creates a real `QuickShareService(...)`:
```swift
self.quickShare = QuickShareService(
    temporaryFileStorage: stubTempStorage,
    sharingStateManager: stubSharing
)
```

`QuickShareService.init()` creates an unstructured `Task { await discoverAvailableProviders() }`.
This Task **inherits task-local values** from its creation context — which is inside the
test's `_observeErrors` scope. The task outlives `_observeErrors`, leaving a stale
reference into the `_observeErrors` task-local allocator.

When the SECOND `_observeErrors` call runs (for test 2), the task-local allocator
finds T_QS's stale allocation violating LIFO order → crash.

This is why:
- Test 1 always passes (first `_observeErrors` call works)
- Test 2 always crashes (second call finds stale T_QS allocation)
- All earlier fix attempts failed (they targeted the Combine sink Task, not T_QS)

## Fix Applied

**`QuickShareService.swift` — init:**
Changed `Task { await discoverAvailableProviders() }` to:
```swift
Task.detached { [weak self] in
    await self?.discoverAvailableProviders()
}
```

`Task.detached` creates a task with NO inherited task-local values (isolated allocator).
T_QS's allocator is completely separate from any `_observeErrors` context.
The task still runs correctly — `await self?.discoverAvailableProviders()` hops to
MainActor as before.

**`MusicPlugin.swift` — setupSubscriptions():**
Added `guard let ms = self.mediaSettings, ms.ambientVisualizerEnabled else { return }`
before audio capture Task creation. The Combine sink Task is now only created when the
visualizer is actually enabled — eliminates another potential `_observeErrors` inheritor.
Uses `Task.detached` for the same reason (no inherited task-locals when it IS created).

**`MusicPluginTests.swift`:**
Restructured from `async throws setUp` + synchronous tests to self-contained
`async throws` test methods. This makes tests match the `ExportCoordinatorTests`
pattern and doesn't rely on XCTest's setUp/tearDown `_observeErrors` machinery.

**`NotchViewModel+Observers.swift` line 38:**
Added `self.hideOnClosed` in nested `withAnimation` closure — was a Swift 6 error.

## All Attempts Made

| Attempt | Why Failed |
|---|---|
| Cancel T1 in sync tearDown | T_QS still inheriting, still pending → crash |
| Task.detached for Combine sink T1 | T_QS (QuickShare) still inheriting → crash |
| Guard ambientVisualizerEnabled (no T1) | T_QS still inheriting → crash |
| async throws tearDown + await deactivate | T_QS in tearDown _observeErrors → crash |
| Remove async setUp; self-contained tests | T_QS still created via QuickShare init → crash |
| **Task.detached for QuickShareService.init** | **T_QS has isolated allocator → no LIFO violation** |

## Files Changed

- `QuickShareService.swift`: `Task { }` → `Task.detached { [weak self] }` in init
- `MusicPlugin.swift`: guard audio Task on `ambientVisualizerEnabled`; use `Task.detached`
- `MusicPluginTests.swift`: self-contained `async throws` test methods (no setUp/tearDown)
- `NotchViewModel+Observers.swift`: explicit `self.hideOnClosed` in `withAnimation`
