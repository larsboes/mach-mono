# 0007 — Native Bazel Builds (Full Migration)

- Status: Accepted
- Date: 2026-05-04
- Supersedes: [0006](0006-deferred-native-bazel-builds.md)

## Context

ADR 0006 deferred native Bazel builds due to `apple_crosstool_top` toolchain transition errors with `rules_apple 4.1.0` on Bazel 9.x. The `apple_crosstool_top` command-line option was removed in Bazel 9, and `rules_apple 4.1.0` still referenced it in `transition_support.bzl`.

## Decision

Upgrade the dependency triple to versions with explicit Bazel 9.x LTS support:

| Dependency | Old | New |
|---|---|---|
| `apple_support` | 1.24.2 | 2.5.4 |
| `rules_apple` | 4.1.0 | 4.5.3 |
| `rules_swift` | 3.1.2 | 3.6.1 |

Removed:
- `register_toolchains("@rules_swift//swift/toolchains:all")` — auto-registered via Bzlmod in rules_swift 3.x.
- `--apple_platform_type=macos` from `.bazelrc` — part of the same removed-in-Bazel-9 Apple flag family.
- `rules_xcodeproj` — not used; IDE integration is handled by opening the existing `.xcodeproj` files in Xcode directly.

## Consequences

- `bazel build //Apps/machNotch:machNotch` works natively without a generated Xcode project detour.
- `bazel build //Apps/machBrief:machBrief` works natively.
- `bazel test //Packages/MachBriefKit:MachBriefKitTests` is the MachBriefKit verification target.
- All new features and packages must define Bazel targets.
- XPC service embedding (`MachNotchXPCHelper`) requires further work — currently compiled separately, embedding deferred (see roadmap Phase 2).
