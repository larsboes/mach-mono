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
