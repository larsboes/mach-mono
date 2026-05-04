# 0003 — License policy for new code

- Status: Accepted
- Date: 2026-05-04

## Context

`machNotch` inherited GPL v3 licensing from its BoringNotch history. The long-term goal is to reengineer inherited code and move the root and machNotch to MIT when legally and technically appropriate. New clean-slate apps and packages do not need to inherit that constraint.

## Decision

New apps and packages target MIT from creation.

Do not add GPL or MPL dependencies to new clean-slate apps or packages. For machNotch plugins inspired by GPL projects, independently reimplement the feature, write no code from the reference project, and document a license note in the relevant PRD spec.

## Consequences

- `repo.yaml` tracks current and target license state.
- `docs/prds/machNotch.md` remains the source of truth for the machNotch GPL-to-MIT migration plan.
- Root `/LICENSE` should be updated only after machNotch is clean for relicensing.
