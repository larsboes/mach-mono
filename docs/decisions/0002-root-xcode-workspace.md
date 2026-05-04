# 0002 — Root Xcode workspace as primary entrypoint

- Status: Accepted
- Date: 2026-05-04

## Context

`mach-mono` is a monorepo with app projects under `Apps/` and shared packages under `Packages/`. The root workspace currently references `Apps/machNotch/machNotch.xcodeproj` and is the intended place to grow the suite.

## Decision

Use `mach-mono.xcworkspace` as the primary Xcode entrypoint for repo-level verification.

The primary scheme is `machNotch`.

## Consequences

- Root build/test instructions should prefer `xcodebuild -workspace mach-mono.xcworkspace -scheme machNotch ...`.
- App-specific instructions may include local project commands, but should not contradict the root workspace entrypoint.
- When workspace topology changes, update `repo.yaml`, `docs/README.md`, root `README.md`, and app instructions together.
