# 0006 — Deferred Native Bazel Builds via rules_xcodeproj

- Status: Superseded by [0007](0007-native-bazel-builds.md)
- Date: 2026-05-04

## Context

We encountered fundamental incompatibilities between Bazel configuration transitions (specifically `apple_crosstool_top`) and our current environment when attempting to build native `macos_application` targets with `rules_apple` 4.1.0.

## Decision

To avoid stalling monorepo growth, we are delegating the primary build task to generated Xcode projects via `rules_xcodeproj`. Bazel will maintain the dependency graph and package definitions, but the actual compilation and bundling will be handled by Xcode until we resolve the underlying toolchain transition errors in pure Bazel.

## Consequences

- **Architectural Debt:** This creates a dependency on generated projects that we aim to eliminate.
- **Maintenance:** We must maintain `BUILD.bazel` files with high accuracy so that the generated Xcode project remains functional.
- **Resolution:** This is a temporary detour. We will revisit pure native Bazel builds once our toolchain configuration is stabilized or a newer Bazel/rules_apple version resolves the transition incompatibility.
