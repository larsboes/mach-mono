# Plan: Bazel-first CI Migration

**Status:** In Progress
**Branch:** dev

---

## Context

Current CI is 100% Xcode-based (`xcodebuild` across all workflows). Bazel builds already work locally (`bazel build //Apps/machNotch:machNotch`, `//Apps/machBrief:machBrief`, `bazel test //Packages/MachBriefKit:MachBriefKitTests`). Goal: make Bazel the sole CI build system.

**Existing workflows:**

| File | Role | Current toolchain |
|---|---|---|
| `cicd.yml` | PR/push build + test | `xcodebuild` (workspace) |
| `build_reusable.yml` | Signed build, DMG, artifact | `xcodebuild archive/export` |
| `release.yml` | Tag → release: appcast + gh release | Xcode-signed |
| `manual_build.yml` | Manual dispatch | Xcode-signed |
| `arch-check.sh` | Architecture conventions (Ubuntu) | Bash/grep only — unchanged |

**Known gaps before this plan:**
- No `.bazelversion` file — bazelisk unpinned
- No `swift_test` target for machNotch's 53 unit tests (Xcode-only)
- `minimum_os_version = "15.0"` in machNotch BUILD.bazel — stale (should be 26.0)
- `Apps/machNotch/CLAUDE.md` build commands still reference xcodebuild

---

## Phase 1 — Fast CI (`cicd.yml`) `[low risk, high value]`

**Goal:** Every push/PR validates via Bazel. Xcode gone from the hot path.

- [ ] Add `.bazelversion` pinning Bazel 9 (matches ADR 0007)
- [ ] Add `--config=ci` to `.bazelrc` with CI flags: `--noshow_progress`, `--show_result=0`, `--color=no`, `--keep_going`
- [ ] Rewrite `cicd.yml`:
  - GitHub Actions cache for `~/.cache/bazel` keyed on `MODULE.bazel` + `Package.resolved`
  - **build job:** `bazelisk build //Apps/machNotch:machNotch //Apps/machBrief:machBrief`
  - **test job:** `bazelisk test //Packages/MachBriefKit:MachBriefKitTests`
  - Keep `arch-check` job unchanged
- [ ] Fix `minimum_os_version = "15.0"` → `"26.0"` in `Apps/machNotch/BUILD.bazel`
- [ ] Fix `Apps/machNotch/CLAUDE.md` build/test commands (still has xcodebuild)

**Note:** machNotch's 53 unit tests do not yet run in Bazel CI — no Bazel test target exists. Addressed in Phase 2.

---

## Phase 2 — machNotch Bazel test target `[medium complexity]`

**Goal:** The 53 machNotch unit tests run in CI under Bazel.

Tests today live in Xcode only. They are pure unit tests (NotchStateMachineTests, NotchHoverControllerTests, etc.) that should compile standalone with mocked services.

- [ ] Audit test files for AppKit/UI dependencies vs pure logic
- [ ] Add `swift_test` target to `Apps/machNotch/BUILD.bazel` with dep on `machNotch_Lib`
- [ ] Wire into `cicd.yml` test job: add `//Apps/machNotch:machNotchTests`
- [ ] Fix any test files that don't compile under Bazel (hidden implicit deps surfaced by strict module isolation)

**Risk:** Test files may rely on Xcode implicit linking. Phase 2 is isolated — cannot break Phase 1.

---

## Phase 3 — Signed release pipeline (`build_reusable.yml`) `[complex]`

**Goal:** Release DMGs produced by Bazel, not `xcodebuild archive`.

**Strategy:** Bazel builds the `.app`, post-build scripts handle signing + DMG. Standard pattern for Bazel + macOS — clean separation between compilation (Bazel) and distribution signing (codesign).

- [ ] **Version injection** — replace `sed project.pbxproj` with Bazel workspace stamping:
  - Add `tools/workspace_status.sh` emitting `STABLE_VERSION` and `STABLE_BUILD_NUMBER` from env vars
  - Add `stamp = True` to `macos_application` in `Apps/machNotch/BUILD.bazel`
  - Patch `bazel_info.plist` to use `{STABLE_VERSION}` / `{STABLE_BUILD_NUMBER}` (already wired as second infoplist)

- [ ] **Compilation step** — replace `xcodebuild clean archive` with:
  ```
  bazelisk build //Apps/machNotch:machNotch \
    --stamp \
    --define=VERSION=${{ inputs.version }} \
    --define=BUILD_NUMBER=${{ github.run_number }}
  ```

- [ ] **Signing step** — sign the Bazel output `.app`:
  ```bash
  APP_PATH=$(bazelisk cquery //Apps/machNotch:machNotch --output=files)
  codesign --deep --force --sign "$CODE_SIGN_IDENTITY" "$APP_PATH"
  ```
  Certificate installation block (`security import`) stays identical.

- [ ] **DMG step** — `create_dmg.sh` takes a `.app` path — no changes, point at `bazel-bin/Apps/machNotch/machNotch.app`

- [ ] **Remove** from `build_reusable.yml`: `Resolve Swift packages`, `Select Xcode`, `xcodebuild archive`, `xcodebuild export`

- [ ] `release.yml` publish job — unchanged (operates on DMG artifact)

**What stays:** certificate import, DMG creation, Sparkle appcast generation, GitHub release creation.

---

## Sequencing

```
Phase 1  →  Phase 2  →  Phase 3
(1-2h)      (2-4h)      (4-6h)
```

Phase 1 and 2 are independent of release infra — safe to merge separately.
Phase 3 requires Phase 1 (shared `.bazelrc` CI config).

---

## Progress

- [ ] Phase 1 complete
- [ ] Phase 2 complete
- [ ] Phase 3 complete
