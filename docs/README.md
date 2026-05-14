# mach-mono Documentation

This directory is the human-readable documentation hub for `mach-mono`.

For structured repo facts, use [`../repo.yaml`](../repo.yaml). For centralized agent guidelines, use [`AGENT-GUIDELINES.md`](AGENT-GUIDELINES.md).

## Where the overall model is defined

There is **no single file** that replaces the layers below; together they are the model:

| Layer | Role | File(s) |
|------|------|---------|
| **Facts** | What is true right now (paths, schemes, policies, pointers) | [`../repo.yaml`](../repo.yaml) |
| **Agent Guidelines** | How coding agents should work in this repo | [`AGENT-GUIDELINES.md`](AGENT-GUIDELINES.md) |
| **Product direction** | What each product should become, phases, status | [`prds/`](prds/) |
| **Decisions (why)** | ADRs for durable choices | [`decisions/`](decisions/) |
| **Architecture & how-tos** | Design reference and guides | [`architecture/`](architecture/), [`guides/`](guides/) |
| **Tool adapters** | Cursor, Claude Code, workflows — consume the above | [`../CLAUDE.md`](../CLAUDE.md), [`../.cursor/`](../.cursor/), [`../.claude/`](../.claude/), [`../.agent/`](../.agent/) |

**Human-friendly index:** this file (`docs/README.md`). **Repo landing:** [`../README.md`](../README.md) links here and to the fact/guideline entrypoints.

Rule of thumb from [`AGENT-GUIDELINES.md`](AGENT-GUIDELINES.md): `repo.yaml` says what is true; `AGENT-GUIDELINES.md` says how agents behave; PRDs say what products should become; decisions say why; adapters say how each tool should read those.

## Where to start

- **New to the repo?** Open [`../README.md`](../README.md), then [`../repo.yaml`](../repo.yaml) for paths, schemes, and policies.
- **Contributing or automating?** Read [`AGENT-GUIDELINES.md`](AGENT-GUIDELINES.md) first.
- **Product scope and current work?** See [`prds/machNotch.md`](prds/machNotch.md) (active app); front matter and the “Current State” section list active phases.
- **Why a convention exists?** See [`decisions/`](decisions/).

## Source-of-truth map

| Concern | Canonical location | Notes |
|---|---|---|
| Structured repo facts | [`../repo.yaml`](../repo.yaml) | Machine-readable facts and pointers. |
| Agent guidelines | [`AGENT-GUIDELINES.md`](AGENT-GUIDELINES.md) | Centralized instruction for AI coding agents. |
| Claude adapter | [`../CLAUDE.md`](../CLAUDE.md) | Thin Claude-specific entrypoint. |
| Product plans | [`prds/`](prds/) | PRDs, phases, feature specs, and product roadmap details. |
| Architecture | [`architecture/overview.md`](architecture/overview.md) | System architecture reference. |
| Guides | [`guides/`](guides/) | Practical guides and how-tos. |
| Roadmaps | [`roadmaps/`](roadmaps/) | Technical migration and build-system plans. |
| Decisions | [`decisions/`](decisions/) | ADR-style records explaining why important choices were made. |

## Agent and tooling files (adapters only)

These files should **point to** the table above, not restate it.

| Location | Role |
|----------|------|
| [`../AGENT-GUIDELINES.md`](AGENT-GUIDELINES.md) | Cross-tool agent behavior and high-signal repo conventions. |
| [`../CLAUDE.md`](../CLAUDE.md) | Thin Claude Code entry; read `AGENT-GUIDELINES.md` and `repo.yaml` first. |
| [`../.cursor/`](../.cursor/) | Cursor rules — short hooks into canonical docs. |
| [`../.claude/`](../.claude/) | Claude Code–local config, rules, and skills. |
| [`../.agent/`](../.agent/) | Reusable **workflows** and skills; start with [`../.agent/README.md`](../.agent/README.md). |

## Product PRDs

- [`prds/machNotch.md`](prds/machNotch.md) — active machNotch implementation plan, feature roadmap, debt triage, and license migration.
- [`prds/machBrief-macOS.md`](prds/machBrief-macOS.md) — macOS machBrief product spec (app in development).
- [`prds/machBrief-iOS.md`](prds/machBrief-iOS.md) — planned iOS machBrief product spec.

## Architecture and guides

- [`architecture/overview.md`](architecture/overview.md) — machNotch architecture overview.
- [`guides/plugin-development.md`](guides/plugin-development.md) — plugin development guide.
- [`guides/sideloading.md`](guides/sideloading.md) — free Apple ID sideloading guide.

## Roadmaps

- [`roadmaps/bazel.md`](roadmaps/bazel.md) — Bazel/Bzlmod orchestration roadmap.

## Decisions

- [`decisions/0001-main-only-branching.md`](decisions/0001-main-only-branching.md)
- [`decisions/0002-root-xcode-workspace.md`](decisions/0002-root-xcode-workspace.md) *(superseded by 0007)*
- [`decisions/0003-license-policy.md`](decisions/0003-license-policy.md)
- [`decisions/0004-bazel-orchestration.md`](decisions/0004-bazel-orchestration.md)
- [`decisions/0005-weather-provider-strategy.md`](decisions/0005-weather-provider-strategy.md)
- [`decisions/0006-deferred-native-bazel-builds.md`](decisions/0006-deferred-native-bazel-builds.md) *(superseded by 0007)*
- [`decisions/0007-native-bazel-builds.md`](decisions/0007-native-bazel-builds.md)
- [`decisions/0008-test-isolation-under-xctest-async.md`](decisions/0008-test-isolation-under-xctest-async.md)
- [`decisions/0009-bazel-ci-migration.md`](decisions/0009-bazel-ci-migration.md)

## Maintenance rules

1. Keep stable facts in `repo.yaml`, not duplicated across docs.
2. Keep detailed product scope and implementation status in PRDs.
3. Capture durable technical/product decisions as ADRs in `docs/decisions/`.
4. Keep tool-specific files (`.cursor/`, `.claude/`, `.agent/`, root `CLAUDE.md`) as adapters that reference the canonical docs.
5. When moving docs, update references in `README.md`, `AGENTS.md`, `CLAUDE.md`, PRDs, workflows, and issue templates.
