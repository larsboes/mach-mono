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
XCTFailableInvocation.invokeAsynchronousBlock
_shouldContinueAfterPerformingSetUpSequenceWithSelector
```

`async throws setUp` on a `@MainActor` XCTestCase subclass triggers `_observeErrors`
for EVERY test in the class. The first call succeeds. The second call corrupts the
task-local LIFO allocator and crashes in `_swift_task_dealloc_specific`.

This happens regardless of what the setUp body contains. We confirmed:
- With no unstructured Tasks created
- With `Task.detached` (no inherited task-locals)
- With await-on-task inside async tearDown

ALL crash on the second test. This is a pure XCTest bug.

`async throws test methods` do NOT trigger this bug. `ExportCoordinatorTests` is
evidence: it has 7 `async throws` test methods on a `@MainActor` class with no
setUp/tearDown, and all pass.

## Fix Applied

**Restructure MusicPluginTests to eliminate `async throws setUp` entirely.**

Instead of setUp/tearDown, each test is self-contained:

```swift
private func makeActivatedPlugin() async throws -> (MusicPlugin, MockMusicService) { ... }

func testDisplayRequestWhenPlaying() async throws {
    let (plugin, mock) = try await makeActivatedPlugin()
    defer { plugin.deactivate_cancelOnly() }
    // test body
}
```

`async throws test methods` on `@MainActor` do not trigger the `_observeErrors` bug.
Each test activates and deactivates its own plugin instance.

**Also applied:** `MusicPlugin.setupSubscriptions()` guards audio task creation on
`ambientVisualizerEnabled` — prevents no-op Tasks (and was the initial fix attempt).
`Task.detached` is kept for production correctness (no inherited task-locals).

**`NotchViewModel+Observers.swift` line 38:** Added `self.` in nested `withAnimation`
closure — was a Swift 6 error.

## All Attempts Made

| Attempt | Result |
|---|---|
| Synchronous tearDown + `deactivate_cancelOnly()` | Test 1 passes; tests 2-3 crash in setUp |
| `Task.detached` alone | Tests 2-3 still crash (inherited task-locals not the cause) |
| async throws tearDown + `await deactivate()` | All tests crash in tearDown _observeErrors |
| Guard task on `ambientVisualizerEnabled` | Test 1 passes; test 2 still crashes (no tasks, bug is in setUp machinery) |
| **Remove async throws setUp; self-contained async throws tests** | **✓ Bug never triggered** |

## Files Changed

- `MusicPlugin.swift`: guard audio Task on `ambientVisualizerEnabled`; use `Task.detached`
- `MusicPluginTests.swift`: remove setUp/tearDown; each test is self-contained `async throws`
- `NotchViewModel+Observers.swift`: explicit `self.hideOnClosed` in `withAnimation`
