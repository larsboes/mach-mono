# 0004 — Bazel as exploratory orchestration

- Status: Accepted
- Date: 2026-05-04

## Context

The repository has Bzlmod files and a Bazel roadmap. Xcode remains the primary day-to-day Apple platform build entrypoint, while Bazel is being evaluated for cross-platform orchestration as the monorepo grows.

## Decision

Treat Bazel as exploratory orchestration until the roadmap graduates it to primary build infrastructure.

Keep the roadmap in `docs/roadmaps/bazel.md` instead of a root-level `BAZEL.md` so it is clearly part of docs, not a competing build source of truth.

## Consequences

- Root workspace verification remains the default for Swift/Xcode changes.
- Bazel docs should describe current migration status and not imply full production ownership until true.
- If Bazel becomes primary, update `repo.yaml`, root `README.md`, docs index, CI docs, and app instructions together.
