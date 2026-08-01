---
id: machnotch-performance
product: machNotch
status: active
owner: larsboes
source_of_truth: true
related:
  app: Apps/machNotch
  agent_instructions: Apps/machNotch/CLAUDE.md
last_updated: 2026-07-11
---

# machNotch — Performance & Lightweight Improvements Plan

**Goal:** Reduce CPU/battery overhead, eliminate redundant observation churn, and tighten animation rendering in machNotch. All changes should be imperceptible to the user while improving efficiency.

**Methodology:** Measure before/after using Xcode Energy Log + Time Profiler where possible.

---

## Improvement Inventory (priority order)

### P0 — Hover Heartbeat Frequency (battery)

**File:** `Apps/machNotch/machNotch/Core/NotchHoverController.swift`

**Problem:** `startHeartbeat()` polls `NSEvent.mouseLocation` every 32ms (31Hz) while the notch is open, even when the mouse is stationary. This keeps the CPU awake unnecessarily.

**Fix:** Vary the polling interval based on mouse activity:
- Mouse moving → 16ms (60Hz, responsive)
- Mouse stationary → 100ms (10Hz, lightweight)
- Detect movement by comparing mouseLocation between ticks

**Status:** ✅ Done

### P0 — State Machine Dirty-Check Guard

**File:** `Apps/machNotch/machNotch/Core/NotchStateMachine.swift`

**Problem:** `update()` runs the full `computeDisplayState()` decision tree (10+ priority branches, multiple service accesses) on every observed property change — including closed-notch sizing ticks, music playback state pings, etc.

**Fix:** Cache the last `NotchStateInput` and skip the full evaluation if the input hasn't changed.

**Status:** ✅ Done

### P1 — Unify Observation Tracking Loops

**File:** `Apps/machNotch/machNotch/AppObjectGraph.swift`

**Problem:** `startObservationTracking()` spawns **6 separate perpetual tasks**, each using `withObservationTracking` + `withCheckedContinuation` + `Task.sleep`. This means 6 separate continuations and 6 wake-up chains for every observed property change.

**Fix:** Merge all 6 loops into a **single unified task** that observes all properties at once and dispatches multiple handlers from one continuation resume.

**Files involved:**
- `AppObjectGraph.swift` — 6 observation tasks
- `NotchViewModel+Observers.swift` — `setupSizeObserver` task
- `NotchObserverSetup.swift` — detector observer tracking tasks
- `NotchStateMachine.swift` — own observation tracking loop

**Status:** ✅ Done — Reduced from 6 tasks to 3 (2 Defaults.updates + 1 withObservationTracking)

### P1 — Consolidate Dual withAnimation Blocks in Phase Transitions

**File:** `Apps/machNotch/machNotch/Core/NotchPhaseCoordinator.swift`

**Problem:** `open()` fires **two** separate `withAnimation` blocks (shell + content), each creating its own animation transaction + completion closure. Close does the same. This doubles the animation bookkeeping overhead on every open/close.

**Fix:** Merge shell + content animations into a single `withAnimation` block. The content stagger effect (shell leads, content follows) can be achieved via `Animation.delay()` on a single animatable property, eliminating the need for a separate animation driver.

**Status:** ✅ Done — Merged shell + content into single withAnimation block; stagger preserved via delayed Task

### P2 — Debounce Task Cleanup (try? pattern)

**File:** `Apps/machNotch/machNotch/ViewModel/NotchViewModel+Observers.swift`

**Problem:** `hideOnClosedDebounceTask` and `earsDebounceTask` use `do/catch` + `Task.sleep` when `try?` + nil-check is more lightweight.

**Fix:** Replace `do { try await Task.sleep(...) } catch { return }` with `try? await Task.sleep(...)` + `guard !Task.isCancelled`.

**Status:** ✅ Done

### P2 — Ears Observation Loop: Remove Redundant Pre-Read

**File:** `Apps/machNotch/machNotch/ViewModel/NotchViewModel+Observers.swift`

**Problem:** `beginClosedEarsObservationLoop()` calls `withObservationTracking` twice per iteration — once as a no-op read, then again as a continuation. The first is unnecessary.

**Fix:** Remove the initial `let _ = withObservationTracking { ... } onChange: { }` block.

**Status:** ✅ Done

### P3 — Event Bus: Typed Dispatch Map

**File:** `Packages/NotchPlugins/Sources/NotchPlugins/Core/PluginEventBus.swift` (stable — verify)

**Problem:** The event bus broadcasts every event to all subscribers (O(n) per event). With 10+ active plugins, HUD events (volume/brightness, firing rapidly) cause unnecessary closure invocations on every plugin.

**Fix:** Use a typed dispatch map `[ObjectIdentifier: [Subscriber]]` so events reach only subscribers that registered for that type.

**Status:** ⏸ Deferred — PluginEventBus is marked stable per CLAUDE.md. Requires separate PR with thorough testing.

---

## Execution Order

```
Phase 1 (P0 items): Hover heartbeat + State machine dirty check
Phase 2 (P1 items): Observation loops + Animation consolidation
Phase 3 (P2 items): Debounce cleanup + Ears pre-read removal
Phase 4 (P3 items): Event bus typed dispatch (if appropriate)
```

Each phase → build, then commit. See [refactoring skill](../.agents/skills/refactoring/SKILL.md) for commit granularity.
