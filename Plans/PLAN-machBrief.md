---
id: machbrief-implementation
status: in_progress
owner: larsboes
source_of_truth: true
related:
  macos_prd: Plans/PRDs/machBrief-macOS.md
  ios_prd: Plans/PRDs/machBrief-iOS.md
  package: Packages/MachBriefKit
  app: Apps/machBrief
  architecture: docs/Architecture.md
last_updated: 2026-06-13
---

# machBrief Implementation Plan

**Goal:** Ship mach.brief macOS v1 as a small, local-first daily content feed,
then reuse the same source/sink model for iOS v2. The PRDs own product scope;
this plan owns implementation order and current repo reality.

## Current State — 2026-06-13

- `Apps/machBrief` exists with a SwiftUI app, Today/Archive/Source Settings
  views, SwiftData persistence, and a WidgetKit target.
- `Packages/MachBriefKit` exists with the source/sink architecture, daily
  scheduler, settings, brief models, bundled resources, dictionary cache/API
  support, and tests.
- Bazel targets exist for both the app and package.
- macOS is the active implementation target. iOS remains v2 and should not
  block macOS v1.

## M0 — Repo Alignment

**Status:** in progress

- Keep the app thin and move reusable source/sink/scheduler logic into
  `MachBriefKit`.
- Keep bundled facts, quotes, mantras, and vocabulary in
  `Packages/MachBriefKit/Sources/MachBriefKit/Resources/`.
- Verify with:

```bash
bazelisk build //Apps/machBrief:machBrief
bazelisk test //Packages/MachBriefKit:MachBriefKitTests
```

## M1 — macOS v1 Experience

**Status:** planned

- Finish Menu Bar / popover behavior around Today, Archive, and Settings.
- Ensure the four daily slots are deterministic and survive relaunch.
- Wire NotificationSink permission flow and delivery.
- Keep onboarding minimal: source selection plus notification/widget prompt.

Definition of done:

- First launch can enable sources, produce today's slot entries, and persist
  archive entries.
- Notifications fire at configured slot boundaries.
- Widget displays the current slot without needing the app foregrounded.

## M2 — Data And Sync Hardening

**Status:** planned

- Finalize SwiftData schema migration strategy for stored brief entries.
- Confirm ObsidianSink behavior and failure handling.
- Add deterministic tests for scheduler/date-boundary behavior and source
  selection.

## M3 — iOS v2 Prep

**Status:** planned

- Keep iOS-specific widgets/intents in the app layer.
- Reuse `MachBriefKit` contracts where possible.
- Do not introduce cloud sync or accounts; keep local-first posture.

## Non-Goals For This Plan

- No AI-generated content in macOS v1.
- No Android implementation here; Android remains a future Kotlin/Compose
  reimplementation of the source/sink model.
- No machSound or HealthKit dependency in macOS v1.
