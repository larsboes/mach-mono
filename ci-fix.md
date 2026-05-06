# CI Fix Analysis — MusicPluginTests crash on macOS 26

## Status: FIXED

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
2. `setUp` is `async throws`
3. An unstructured `Task { @MainActor }` was enqueued during the synchronous test body  
   (specifically, when `mockMusicService.playbackState` is set → Combine sink → `Task` appended to `activeTasks`)

The unstructured `Task { @MainActor }` inherits task-local values from whatever async context  
is active when it's created. On macOS 26, this creates a shared allocator relationship  
with XCTest's `_observeErrors` task-local chain. When test 1's `Task` outlives its setUp's  
async context, test 2's `_observeErrors` encounters stale task-local allocations → LIFO  
order violation → `freed pointer was not the last allocation` → Signal 6.

Crash stack (abbreviated):
```
_swift_task_dealloc_specific                          ← wrong dealloc order
XCTSwiftErrorObservation._observeErrors(in:)
XCTFailableInvocation.invokeAsynchronousBlock
_performSetUpSequenceWithSelector (or tearDown)
```

## What Was Tried (partial fixes)

| Attempt | Result |
|---|---|
| Cancel + removeAll in deactivate | No change — crash still in tearDown |
| `guard !Task.isCancelled` in task body | No change — tasks aren't the root cause |
| Cancel subscriptions before tasks in deactivate | No change |
| Await tasks (`for task in tasks { _ = await task.value }`) | No change |
| `tearDown() async` (drop throws) | Compile error — base class is `async throws` |
| Synchronous `tearDown()` + `wait(for:)` | Deadlock + AppKit assertion on MainActor |
| Synchronous `tearDown()` + `deactivate_cancelOnly()` | test 1 passes, test 2 still crashes |

## Fix Applied

**`MusicPlugin.swift` — `setupSubscriptions()`**

Changed the unstructured task from `Task { @MainActor [weak self] in }` to  
`Task.detached { @MainActor [weak self] in }`.

`Task.detached` creates a task with **no inherited task-local values**. This means the task  
has its own isolated allocator pool, completely separate from any XCTest `_observeErrors`  
context. There is no shared state for the LIFO-order deallocation to corrupt.

The change is safe in production:
- `@MainActor` on the closure body maintains correct actor isolation
- Cancellation still works — we cancel explicitly via `activeTasks.forEach { $0.cancel() }`
- `guard !Task.isCancelled` still fires correctly on detached tasks
- Priority defaults to `.medium` (was inherited previously) — no observable audio lag

**`MusicPluginTests.swift` — tearDown**

Remains synchronous (avoids `async throws tearDown` going through `_observeErrors`):
```swift
override func tearDown() {
    plugin.deactivate_cancelOnly()
    plugin = nil
    mockMusicService = nil
    context = nil
}
```

**`NotchViewModel+Observers.swift:38`**  
Added explicit `self.hideOnClosed = shouldHide` inside nested `withAnimation` closure —  
was a Swift 6 warning (`this is an error in Swift 6 language mode`).

## Changes Made

**`MusicPlugin.swift`**
- `setupSubscriptions()`: `Task { @MainActor }` → `Task.detached { @MainActor }` with comment
- `deactivate()`: cancel subscriptions first, then cancel+await tasks (stays correct with detached)
- `deactivate_cancelOnly()`: synchronous cancel for test teardown (stays correct)

**`MusicPluginTests.swift`**
- `tearDown()` is synchronous, calling `deactivate_cancelOnly()`

**`NotchViewModel+Observers.swift`**
- `hideOnClosed = shouldHide` inside `withAnimation` → `self.hideOnClosed = shouldHide`
