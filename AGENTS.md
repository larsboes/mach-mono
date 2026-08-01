# Agents

## Skills (source of truth)

Agent skills live in **`.claude/skills/`** and are automatically synced to `.gemini/skills/` and `.cursor/skills/` via `tools/sync-skills.sh`.

| Skill | Invocation | Scope |
|---|---|---|
| `plugin-architecture` | auto (Claude) | `**/Plugins/**/*.swift` |
| `swift-code-quality` | auto (Claude) | `**/*.swift` |
| `swift` | auto (Claude) | `**/*.swift` |
| `swift-concurrency` | auto (Claude) | `**/*.swift` |
| `refactoring` | auto (Claude) | all files |
| `design-system` | auto (Claude) | UI/view files |
| `git-flow` | `/git-flow` (user) | — |
| `save-context` | `/save-context` (user) | — |

To update a skill: edit the file in `.claude/skills/<name>/SKILL.md`, then run `task skills:sync`.

## Full Reference

Deep architecture docs, protocol hierarchies, and feature specs live in:

- [`docs/AGENT-GUIDELINES.md`](docs/AGENT-GUIDELINES.md) — full human-readable reference
- [`repo.yaml`](repo.yaml) — structured repo facts, product paths, policies
- [`docs/README.md`](docs/README.md) — documentation index
- [`Apps/machNotch/CLAUDE.md`](Apps/machNotch/CLAUDE.md) — app-local rules

## Learned User Preferences

- Prefer larger, fewer commits during solo refactoring; splitting every file edit into separate commits is unnecessary.
- When implementing attached plans, do not edit the plan file itself; use existing todos and mark them in progress/completed.
- Push through to green builds and tests rather than stopping at pre-existing Xcode project blockers.
- Weather: OpenWeatherMap is the primary provider; WeatherKit is fallback only when available.
- UI motion (e.g. weather condition animations) should stay minimal, aesthetic, and light on system resources.
- Use machNotch/mach-mono naming in docs and paths; detach from boringNotch fork naming except attribution and license history.

## Learned Workspace Facts

- Canonical structured repo facts live in `repo.yaml`; `AGENTS.md` and `CLAUDE.md` are thin adapters pointing to it.
- Primary macOS product is machNotch (`Apps/machNotch`); machBrief (`Apps/machBrief` + `Packages/MachBriefKit`) is in active development.
- Bazel is the active build orchestrator for packages and CI; the root Xcode workspace is for IDE navigation.
- machNotch is undergoing deliberate MIT relicensing via file-by-file reengineering of fork-derived code.
- Built-in plugins register through `PluginRegistry.makeBuiltInPlugins()` in the machNotch app.
- MachSound audio uses the `MachSoundDSP` package module (custom DSP rewrite); prototype parity remains an active goal.
