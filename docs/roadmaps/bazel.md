---
id: bazel-roadmap
status: in_progress
source_of_truth: true
related:
  repo_manifest: repo.yaml
  decision: docs/decisions/0007-native-bazel-builds.md
---

# Bazel Monorepo Roadmap

Bazel (Bzlmod) is the primary build and orchestration layer for this monorepo. Xcode remains the IDE entrypoint; all builds go through `bazel build`.

## Phase 1: macOS Foundation

1. [x] **Install Bazel:** Used `bazelisk`.
2. [x] **Initialize Monorepo:** Setup `MODULE.bazel` with `rules_apple`, `rules_swift`.
3. [x] **Create Shared Core:** Migrated `Packages/` to Bazel `swift_library` targets.
4. [x] **Create macOS App:** Defined `macos_application` target in `Apps/machNotch/BUILD.bazel`.
5. [x] **Native Builds:** Resolved `apple_crosstool_top` toolchain issue — upgraded to `rules_apple 4.5.3`, `rules_swift 3.6.1`, `apple_support 2.5.4`.

## Phase 2: machBrief Integration

1. [x] **machBrief BUILD.bazel:** Defined `macos_application` + `macos_extension` targets.
2. [x] **MachBriefKit Bazel Tests:** Added `swift_test` coverage at `//Packages/MachBriefKit:MachBriefKitTests`.
3. [x] **XPC Service Bundling:** `MachNotchXPCHelper` is wired as an embedded `macos_xpc_service` via `xpc_services` in `Apps/machNotch/BUILD.bazel`.
4. [x] **Code Signing:** Local builds sign via `task run` (Apple Development cert); CI signs Bazel output via `codesign --deep` in `build_reusable.yml`.

## Phase 3: CI/CD

- [x] Replace Xcode-based CI with `bazel build` + `bazel test` in GitHub Actions (cicd.yml fully on `bazelisk --config=ci`).
- [x] Cache remote build results — `~/.cache/bazel-repos` + `~/.cache/bazel` keyed on `MODULE.bazel` / `Package.resolved` / BUILD files.

## Phase 4: iOS / Cross-Platform

- [ ] Create `ios_application` targets reusing `Packages/` modules.
- [ ] Future: Integrate `rules_android` and `rules_kotlin` for machBrief Android.
