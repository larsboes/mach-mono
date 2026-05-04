---
task: check implementation plan completion errors bugs docs
slug: 20260504-120000_check-impl-plan-docs-audit
effort: standard
phase: complete
progress: 10/10
mode: interactive
started: 2026-05-04T12:00:00Z
updated: 2026-05-04T12:05:00Z
---

## Context

Audit of mach-mono docs against current code state. Last commit: `8379640 feat(wip): scaffold SystemStatsPlugin`. 59 files uncommitted (WeatherPlugin refactor, BatteryPlugin refactor, SystemStats WIP, SneakPeekService deletion, NavigationState deletion, entitlements additions). Phase 15 is complete (all success metrics ✅) but Known Bugs section still shows ⚠️ Open for BUG-2 through BUG-7.

### Risks
- Marking bugs fixed without verifying actual code could mislead future readers
- Removing SneakPeekService from CLAUDE.md when the WIP hasn't been committed could cause confusion mid-WIP
- README license claim about Atoll/DockDoor is factually questionable but may be Lars's explicit intent

## Criteria

- [x] ISC-1: CLAUDE.md machNotch line 23 — SneakPeekService removed from Coordinators list
- [x] ISC-2: PRD BUG-2 status updated to ✅ Fixed (Phase 15.1 done, success metric checked)
- [x] ISC-3: PRD BUG-3 status updated to ✅ Fixed (code: fftSetup is optional, guard-let used)
- [x] ISC-4: PRD BUG-4 status updated to ✅ Fixed (code: deinit cancels observerTasks)
- [x] ISC-5: PRD BUG-5 status updated to ✅ Fixed (code: earsTrackingTask cancel-before-re-subscribe)
- [x] ISC-6: PRD BUG-6 status updated to ✅ Fixed (Phase 15.5 addressed try? patterns)
- [x] ISC-7: PRD BUG-7 status updated to ✅ Fixed (code: @MainActor on AudioFFTProcessor)
- [x] ISC-8: README License section — flagged to Lars (Atoll/DockDoor listed as "inspiration" in Acknowledgments but "incorporates code" in License; needs owner decision)
- [x] ISC-9: README Roadmap — SystemStats marked In Progress, add HabitTracker as shipped
- [x] ISC-10: All findings reported clearly to Lars with file:line references

## Decisions

## Verification
