# 0002 — Root Xcode workspace as primary entrypoint

- Status: Superseded by [0007](0007-native-bazel-builds.md)
- Date: 2026-05-04

## Context

`mach-mono` is a monorepo with app projects under `Apps/` and shared packages under `Packages/`. The root workspace currently references `Apps/machNotch/machNotch.xcodeproj` and is the intended place to grow the suite.

## Decision

~~Use `mach-mono.xcworkspace` as the primary Xcode entrypoint for repo-level verification.~~

**Superseded:** Bazel is the primary build and verification system. `mach-mono.xcworkspace` is retained for IDE navigation only — it is not the canonical build entrypoint. See ADR 0007.

## Consequences

- Canonical build: `bazel build //Apps/machNotch:machNotch`
- Canonical test: `bazel test //...`
- `mach-mono.xcworkspace` is IDE scaffolding only — do not use `xcodebuild` as the verification source of truth.
- When workspace topology changes, update `repo.yaml`, `docs/README.md`, root `README.md`, and `MODULE.bazel` together.
