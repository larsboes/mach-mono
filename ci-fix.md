# CI Fix Analysis — MusicPluginTests crash on macOS 26

## Status: FIXED

## Symptom

CI fails on `//Apps/machNotch:machNotchTests`.  
`MusicPluginTests` crashes with `Signal 6 / freed pointer was not the last allocation`.

## Root Cause

**Two-part macOS 26 / Xcode 26 beta (25D125) failure.**

### Crash 1: `_swift_task_dealloc_specific` (Signal 6)
`XCTSwiftErrorObservation._observeErrors` wraps `async throws` test methods with
task-local error observation. It crashes on the 2nd+ test with LIFO order violation.

**Root cause:** `QuickShareService.init()` creates `Task { await discoverAvailableProviders() }`.
This Task **inherits task-local values** from the creating context (the test method's
`_observeErrors` scope). The inherited chain outlives `_observeErrors`, leaving stale
task-local allocations when the 2nd test's `_observeErrors` runs.

### Crash 2: `NSInternalInconsistencyException` / `swift_task_localValuePopImpl` (Signal 11)
`discoverAvailableProviders()` calls `ShareServiceFinder.findApplicableServices()` which
calls `NSSharingServicePicker.showRelativeToRect:ofView:` → `NSRemoteViewController` →
`NSServiceViewController.currentAppIsViewService` which throws:
```
NSInternalInconsistencyException: 'invoked too early to return meaningful value'
```
This NSException thrown from `Task.detached` running on MainActor corrupts the Swift
async task machinery, causing `swift_task_localValuePopImpl` null ptr dereference.

## Fix Applied

**`QuickShareService.swift` — init:**
Added `discoverOnInit: Bool = true` parameter. When `false`, no Task is created:
```swift
init(temporaryFileStorage:, sharingStateManager:, discoverOnInit: Bool = true) {
    ...
    guard discoverOnInit else { return }
    Task.detached { [weak self] in await self?.discoverAvailableProviders() }
}
```

`Task.detached` is also retained (correct for production: no inherited task-locals).

**`MusicPluginTests.swift` — TestNotchServiceProvider:**
```swift
self.quickShare = QuickShareService(
    temporaryFileStorage: stubTempStorage,
    sharingStateManager: stubSharing,
    discoverOnInit: false  ← no AppKit UI work in headless tests
)
```

**Other changes (necessary context):**
- `MusicPlugin.setupSubscriptions()`: guard audio Task on `ambientVisualizerEnabled`
  and use `Task.detached` — eliminates a secondary potential task-local inheritor
- `MusicPluginTests.swift`: self-contained `async throws` test methods (no setUp/tearDown)
  — avoids XCTest `_observeErrors` bug with repeated async setUp invocations
- `NotchViewModel+Observers.swift` line 38: `self.hideOnClosed` in `withAnimation`
  closure — was a Swift 6 error

## All Fix Attempts Made

| Attempt | Why Failed |
|---|---|
| Sync tearDown + `deactivate_cancelOnly()` | T_QS still inheriting/crashing in test 2 setUp |
| `Task.detached` for Combine sink | T_QS (QuickShare) still inheriting → crash |
| Guard audio Task on `ambientVisualizerEnabled` | T_QS still present → crash |
| async throws tearDown + `await deactivate()` | tearDown's own `_observeErrors` crashed |
| Self-contained async throws test methods | T_QS still present → crash |
| `Task.detached` for QuickShareService.init | T_QS no longer inherits, but AppKit exception from discovery crashes via Signal 11 |
| **`discoverOnInit: false` in tests + self-contained tests** | **No Task created, no AppKit work** |

## Files Changed

- `QuickShareService.swift`: `discoverOnInit: Bool = true` param; `Task.detached` in production
- `MusicPlugin.swift`: guard audio Task on `ambientVisualizerEnabled`; `Task.detached`
- `MusicPluginTests.swift`: `discoverOnInit: false`; self-contained `async throws` tests
- `NotchViewModel+Observers.swift`: explicit `self.hideOnClosed` in `withAnimation`
