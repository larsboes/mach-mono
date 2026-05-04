---
id: bazel-roadmap
status: in_progress
source_of_truth: true
related:
  repo_manifest: repo.yaml
  decision: docs/decisions/0004-bazel-orchestration.md
---

# Bazel Monorepo Roadmap

Bazel (Bzlmod) is the intended long-term build and orchestration layer for this monorepo. Xcode via `mach-mono.xcworkspace` remains the primary day-to-day Apple platform entrypoint until this roadmap promotes Bazel targets to parity.

## Phase 1: macOS Foundation
1. [x] **Install Bazel:** Used `bazelisk`.
2. [x] **Initialize Monorepo:** Setup `MODULE.bazel` with `rules_apple`, `rules_swift`, `rules_xcodeproj`.
3. [ ] **Create Shared Core:** Migrating `Packages/` to Bazel `swift_library` targets.
4. [ ] **Create macOS App:** Define `macos_application` target in `Apps/machNotch/BUILD.bazel`.
5. [ ] **Generate Xcode:** Configure `rules_xcodeproj` to generate the workspace.

## Phase 2: iOS Integration
- Create `ios_application` targets reusing `SharedCore` and `Packages/` modules.

## Phase 3: Android Support
- Future: Integrate `rules_android` and `rules_kotlin`.
