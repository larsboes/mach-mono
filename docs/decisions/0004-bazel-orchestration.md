# 0004 — Bazel as primary orchestration

- Status: Accepted
- Date: 2026-05-04

## Context

The repository has Bzlmod files and a Bazel roadmap. As the monorepo grows, we have decided to elevate Bazel from exploratory orchestration to the **primary build and orchestration infrastructure**.

## Decision

Treat Bazel as the source of truth for build orchestration. Xcode will remain the IDE entrypoint, but Bazel targets are now production requirements.

Keep the roadmap in `docs/Roadmap.md` instead of a root-level `BAZEL.md` so it is clearly part of docs.

## Consequences

- Bazel targets now require first-class support.
- All new features and packages must be defined with Bazel targets.
- Update `repo.yaml`, root `README.md`, docs index, CI docs, and app instructions to prioritize Bazel.
