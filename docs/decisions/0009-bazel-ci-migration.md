# 0009 — Bazel-first CI Migration

- Status: Accepted (complete)
- Date: 2026-05-07

## Context

CI was 100% Xcode-based (`xcodebuild` across all workflows). Bazel builds already worked locally. Goal: make Bazel the sole CI build system so builds are hermetic, cacheable, and independent of Xcode version drift.

## Decision

Three-phase migration:

**Phase 1 — Fast CI (`cicd.yml`):** Every push/PR validates via Bazel. Xcode removed from the hot path.

- `.bazelversion` pins Bazel 7.6.1
- `--config=ci` block in `.bazelrc` with all CI flags
- `cicd.yml` uses `bazelisk build/test --config=ci` with dual-layer Actions cache

**Phase 2 — machNotch Bazel test target:** The machNotch unit tests run under Bazel CI via `//Apps/machNotch:machNotchTests`. Test files audited for hidden AppKit deps and extracted into `CommonTestStubs.swift`.

**Phase 3 — Signed release pipeline (`build_reusable.yml`):** Release DMGs produced by Bazel, not `xcodebuild archive`.

- Version injection via Bazel workspace stamping (`tools/workspace_status.sh`, `--stamp`)
- Compilation: `bazelisk build //Apps/machNotch:machNotch --stamp`
- Signing: `codesign --deep --force --sign "$CODE_SIGN_IDENTITY"` on the Bazel output `.app`
- DMG: `create_dmg.sh` pointed at `bazel-bin/Apps/machNotch/machNotch.app`

## Consequences

- Builds are hermetic and cacheable in CI
- Xcode version drift no longer affects compilation
- Release artifacts are produced identically in CI and locally
- `minimum_os_version = "26.0"` enforced at build time

## Source of Truth

- Build graph: `MODULE.bazel`, the root `Package.swift` SwiftPM shim, and package/app `BUILD.bazel` files.
- CI/release orchestration: `.github/workflows/cicd.yml`, `.github/workflows/build_reusable.yml`, and `.github/workflows/release.yml`.
- Dependency security: GitHub dependency graph for supported manifests, `Package.resolved` for Swift package resolution, and `.github/workflows/dependency-security.yml` for PR dependency review plus SBOM artifact export.
