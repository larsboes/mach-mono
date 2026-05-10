# 0008 — Test isolation under XCTest async / macOS 26

- Status: Accepted
- Date: 2026-05-06

## Context

`//Apps/machNotch:machNotchTests` crashed under macOS 26 / Xcode 26 with
two compounding failures inside `MusicPluginTests`:

1. **`_swift_task_dealloc_specific` (Signal 6).**
   `XCTSwiftErrorObservation._observeErrors` wraps `async throws` test
   methods with task-local error observation. `QuickShareService.init()`
   created a child `Task { … }` that **inherited task-local values** from
   the test's `_observeErrors` scope. The inherited chain outlived the
   scope, so the next test's `_observeErrors` saw a LIFO violation.

2. **`NSInternalInconsistencyException` / `swift_task_localValuePopImpl`
   (Signal 11).** Inside that inherited Task,
   `discoverAvailableProviders()` reached `NSSharingServicePicker
   .showRelativeToRect:ofView:` → `NSRemoteViewController` →
   `NSServiceViewController.currentAppIsViewService`, which throws
   `'invoked too early to return meaningful value'` during early app
   bring-up. An NSException thrown from a `Task` running on the main actor
   corrupts Swift's async task machinery and dereferences a null pointer.

Seven fix attempts before landing the right one are recorded below.

## Decision

Two changes:

1. `QuickShareService.init` accepts `discoverOnInit: Bool = true`. Tests
   pass `false` so no `Task` is created, no AppKit work happens, and no
   task-local inheritance can leak across `_observeErrors` scopes.

2. The production path uses `Task.detached`, which has no inherited
   task-locals — defence in depth even when discovery is enabled.

```swift
init(temporaryFileStorage:, sharingStateManager:, discoverOnInit: Bool = true) {
    …
    guard discoverOnInit else { return }
    Task.detached { [weak self] in await self?.discoverAvailableProviders() }
}
```

`MusicPluginTests` constructs the service with `discoverOnInit: false` and
uses self-contained `async throws` test methods (no shared
`setUp`/`tearDown` async context) to avoid repeat `_observeErrors`
invocations.

## Consequences

- `bazelisk test //Apps/machNotch:machNotchTests` is green on macOS 26.
- New tests must avoid creating non-detached `Task`s during `init`s that
  run inside an `async` test method, or they will re-introduce the
  task-local-inheritance bug.
- `MusicPlugin.setupSubscriptions` uses `Task.detached` for its audio
  subscription work and is gated on `ambientVisualizerEnabled`.
- `NotchViewModel+Observers.swift:38` uses `self.hideOnClosed` explicitly
  inside the `withAnimation` closure (Swift 6 strict concurrency
  requirement).

## Files changed

- `Apps/machNotch/machNotch/Plugins/Services/QuickShareService.swift`
- `Apps/machNotch/machNotch/Plugins/BuiltIn/MusicPlugin/MusicPlugin.swift`
- `Apps/machNotch/machNotchTests/Plugins/MusicPluginTests.swift`
- `Apps/machNotch/machNotch/ViewModel/NotchViewModel+Observers.swift`

## Failed attempts (for posterity)

| Attempt | Why failed |
|---|---|
| Sync tearDown + `deactivate_cancelOnly()` | T_QS still inheriting/crashing in test 2 setUp |
| `Task.detached` for Combine sink | T_QS still inheriting → crash |
| Guard audio Task on `ambientVisualizerEnabled` | T_QS still present → crash |
| async throws tearDown + `await deactivate()` | tearDown's own `_observeErrors` crashed |
| Self-contained async throws test methods | T_QS still present → crash |
| `Task.detached` for `QuickShareService.init` | T_QS no longer inherits, but AppKit exception during discovery crashes via Signal 11 |
| **`discoverOnInit: false` in tests + self-contained tests** | **No Task created, no AppKit work** |
