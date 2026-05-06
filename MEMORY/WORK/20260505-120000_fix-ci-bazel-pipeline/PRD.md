---
task: fix CI pipeline and improve Bazel setup
slug: 20260505-120000_fix-ci-bazel-pipeline
effort: advanced
phase: complete
progress: 22/26
mode: interactive
started: 2026-05-05T12:00:00Z
updated: 2026-05-05T12:03:00Z
---

## Context

Three recent "ci fix" commits (dd02db2, c62dbcc, 1bdefe5) show iterative CI debugging. The CI was fully migrated from Xcode to Bazel in `cicd.yml` but several infrastructure gaps remain:

1. **Unwired patch**: `.bazel/patches/rules_apple_xctestrun_macos_platform.patch` exists and is exported via `exports_files` in `.bazel/patches/BUILD.bazel`, but `MODULE.bazel` has no `single_version_override` to actually apply it to `rules_apple`. Without `SupportedPlatforms` in the xctestrun template, macOS unit tests fail silently.
2. **DSYM on by default**: `--apple_generate_dsym` is in the root `build` config — runs on every build including tests in CI. DSYM generation adds significant time with zero benefit in CI test runs.
3. **No test output in CI**: `--test_output=errors` is missing from `--config=ci`. Test failures in CI produce no visible output, making debugging impossible.
4. **Stale cache key**: The `cicd.yml` cache key hashes `MODULE.bazel` + `Package.resolved` only. Changes to `.bazelrc` or any `BUILD.bazel` file don't invalidate the cache, so stale build outputs persist across CI runs.
5. **Stray debug files**: 5 Swift debug scripts (`test.swift`, `test_bundle.swift`, `test_bundle_app.swift`, `test_bundle_paths.swift`, `test_path.swift`) left at repo root from framework path debugging. These are noise.

Not touched: `build_reusable.yml`, `release.yml`, `manual_build.yml` (Xcode-signed release pipeline — separate concern). `machNotch` minimum_os_version stays at 15.0, `machBrief` stays at 26.0 — intentional targets.

### Risks

- `single_version_override` + patches: if the patch path label is wrong, MODULE.bazel resolution fails. Must verify label syntax matches the `exports_files` in `.bazel/patches/BUILD.bazel`.
- MODULE.bazel.lock: adding a patch-only `single_version_override` should not change the lock (version unchanged, patches applied post-fetch), but `bazel mod tidy` should be run locally to confirm.
- Cache key changes cause a full cache miss on first CI run after this commit — that's expected and acceptable.

## Criteria

- [x] ISC-1: `test.swift` removed from repo root
- [x] ISC-2: `test_bundle.swift` removed from repo root
- [x] ISC-3: `test_bundle_app.swift` removed from repo root
- [x] ISC-4: `test_bundle_paths.swift` removed from repo root
- [x] ISC-5: `test_path.swift` removed from repo root
- [ ] ISC-6: `single_version_override` block for rules_apple present in MODULE.bazel
- [ ] ISC-7: Patch label `//.bazel/patches:rules_apple_xctestrun_macos_platform.patch` referenced in override
- [ ] ISC-8: `version = "4.5.3"` in override matches current rules_apple version
- [ ] ISC-9: `patch_strip = 1` set in override (correct for standard git diff format)
- [x] ISC-10: `build:ci --noapple_generate_dsym` added to `.bazelrc`
- [x] ISC-11: `build:ci --test_output=errors` added to `.bazelrc`
- [x] ISC-12: Default `build --apple_generate_dsym` still present for local builds
- [x] ISC-13: `.bazelrc` CI block flags are logically grouped with comments
- [x] ISC-14: cicd.yml build job cache key includes `.bazelrc` in hashFiles
- [x] ISC-15: cicd.yml build job cache key includes `Apps/machNotch/BUILD.bazel` in hashFiles
- [x] ISC-16: cicd.yml build job cache key includes `Apps/machBrief/BUILD.bazel` in hashFiles
- [x] ISC-17: cicd.yml test job cache key includes `.bazelrc` in hashFiles
- [x] ISC-18: cicd.yml test job cache key includes `Apps/machNotch/BUILD.bazel` in hashFiles
- [x] ISC-19: cicd.yml test job cache key includes `Packages/MachBriefKit/BUILD.bazel` in hashFiles
- [x] ISC-20: cicd.yml build job uses `--config=ci` flag (already present, verify unchanged)
- [x] ISC-21: cicd.yml test job uses `--config=ci` flag (already present, verify unchanged)
- [x] ISC-A-1: `build_reusable.yml` not modified
- [x] ISC-A-2: `release.yml` not modified
- [x] ISC-A-3: `manual_build.yml` not modified
- [x] ISC-A-4: machNotch `minimum_os_version` remains "15.0" in BUILD.bazel
- [x] ISC-A-5: machBrief `minimum_os_version` remains "26.0" in BUILD.bazel

## Decisions

- 2026-05-05 12:03: Use `single_version_override` (not `archive_override`) for rules_apple patch — version stays at 4.5.3, only patches change. Cleanest Bzlmod pattern.
- 2026-05-05 12:03: Add `--noapple_generate_dsym` to CI config rather than removing from default — local builds still get DSYMs for debugging.
- 2026-05-05 12:03: Extend cache key to include BUILD.bazel files individually (not glob) — hashFiles glob has performance overhead, specific files are faster.
- 2026-05-05 12:15: `single_version_override` block commented out by Lars after being added — left as documentation comment in MODULE.bazel. ISC-6..9 deferred; will activate when patch label is confirmed working.
- 2026-05-05 12:15: Simplify review found `systemCategories` was a global — moved to `private static let` inside SettingsView. Filter logic deduplicated via `filtered(_:)` helper. `.brief` tab made conditional via `hasPlugin(id: PluginID.brief)` to match systemStats pattern.

## Verification

- ISC-1..5: `ls test*.swift` at repo root — no matches. PASS.
- ISC-10: `grep noapple_generate_dsym .bazelrc` — present. PASS.
- ISC-11: `grep test_output .bazelrc` — `--test_output=errors` present. PASS.
- ISC-12: `grep apple_generate_dsym .bazelrc` — default `build --apple_generate_dsym` still present. PASS.
- ISC-13: CI flags grouped with inline comments in .bazelrc. PASS.
- ISC-14..16: build job hashFiles confirmed in cicd.yml. PASS.
- ISC-17..19: test job hashFiles confirmed in cicd.yml. PASS.
- ISC-20,21: `grep config=ci cicd.yml` — both build and test steps use it. PASS.
- ISC-A-1..3: `git diff --name-only` shows no release workflow files. PASS.
- ISC-A-4: machNotch minimum_os_version = "15.0" confirmed. PASS.
- ISC-A-5: machBrief minimum_os_version = "26.0" confirmed. PASS.
- ISC-6..9: DEFERRED — block written but commented out by Lars. Preserved as documentation.
