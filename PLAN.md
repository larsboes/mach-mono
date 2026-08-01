---
id: mach-mono-master-plan
status: active
owner: larsboes
source_of_truth: true
last_updated: 2026-06-13
related:
  architecture: docs/Architecture.md
  roadmap: docs/Roadmap.md
  docs_index: docs/README.md
  repo_manifest: repo.yaml
---

# mach-mono Master Plan

This is the root execution index for the repo. Keep detailed implementation
notes in `Plans/`; keep this file focused on ordering, dependencies, and the
next plan to pick up.

## Current Order

1. **machNotch architecture hardening**
   - Why first: it protects the plugin boundary that machSound, machBrief, and
     future third-party plugins depend on.
   - Status: completed on 2026-06-13 (architectural specifications consolidated in [Architecture.md](file:///Users/larsboes/Developer/mach-mono/docs/Architecture.md)).

2. **machSound v2 parity stabilization**
   - Plan: `Plans/PLAN-machSound.md`
   - Why second: Soundscape is now integrated into the dev notch path, but the
     native sound/UI still does not match `tmp/fluid-symphony-v2.html`. Fixing
     parity now is more important than adding health adaptation on top of a weak
     instrument.
   - Next: complete M3.5 by freezing `tmp/ENGINE-SPEC.md`, A/B testing each v2
     preset against native Soundscape, tuning voices/mix/visual response, and
     deciding whether AudioKit can reach parity or needs a fallback strategy.

3. **machHealth exporter**
   - Plan: `Plans/PLAN-machHealth.md`
   - Why third: machSound M4 depends on HealthKit data, and macOS cannot read
     HealthKit directly.
   - Next: create `Apps/machHealth` and `Packages/HealthExportKit`, then land
     the versioned LAN JSON export contract.

4. **machSound health integration**
   - Plan: `Plans/PLAN-machSound.md`
   - Why fourth: health adaptation should only land after the instrument itself
     feels good and machHealth exists.
   - Next: wire M4 Health pipeline after machHealth exists.

5. **machIntelligence embeddings**
   - Plan: `Plans/PLAN-machIntelligence.md`
   - Why fourth: Foundation Models, oMLX, and streaming are already integrated;
     the real remaining feature is M4 embeddings/Shelf semantic search.
   - Next: reconcile any remaining plan/code location drift, then implement the
     embedding contract and first semantic-search consumer.

6. **machBrief implementation plan**
   - Plan: `Plans/PLAN-machBrief.md`
   - PRDs: `Plans/PRDs/machBrief-macOS.md`,
     `Plans/PRDs/machBrief-iOS.md`
   - Why fifth: machBrief has app/package code and PRDs; macOS v1 should be
     finished after the shared architecture work settles.
   - Next: finish macOS v1 Menu Bar/widget/notification behavior, with iOS v2 as
     a follow-up.

6. **UX showcase**
   - Plan: `Plans/PLAN-uxShowcase.md`
   - Why last: showcase work should follow stable architecture and visible
     product behavior.
   - Next: record and publish updated machNotch screenshots/video once the
     architecture and Soundscape opt-in work are settled.

## Supporting Product Docs

- machNotch PRD: `Plans/PRDs/machNotch.md`
- machNotch ideas backlog: `Plans/PRDs/machNotch-ideas.md`
- machBrief macOS PRD: `Plans/PRDs/machBrief-macOS.md`
- machBrief iOS PRD: `Plans/PRDs/machBrief-iOS.md`

## Architecture Notes To Keep Visible

- Bazel is canonical for machNotch release and CI builds.
- `Packages/NotchPlugins/Package.swift` is currently a SwiftPM shim and may lag
  the Bazel per-plugin target split. Add SwiftPM parity only if that tool path
  becomes important again.
- Runtime plugin loading is descriptor-based and strict on-demand. The default
  registry no longer constructs built-in plugin instances during startup.
- Soundscape is available through `//Apps/machNotch:machNotchWithSoundscape`;
  the default app target stays free of `Packages/MachSoundKit` dependencies.

## Update Rules

- Update this file when the implementation order changes.
- Update the detailed `Plans/PLAN-*.md` file when milestone scope or definition
  of done changes.
- Update the relevant PRD when product behavior changes.
- Keep `docs/Architecture.md` aligned whenever package boundaries, build
  targets, or dependency direction changes.
