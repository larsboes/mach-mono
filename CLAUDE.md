# Project Guidelines

Agent skills live in **`.claude/skills/`** (source of truth) and define all operative coding rules:

- `plugin-architecture` — plugin protocol, lifecycle, DI, HUD events (auto-loaded for Plugins/)
- `swift-code-quality` — file limits, @Observable, no singletons, no direct Defaults (auto-loaded for *.swift)
- `swift` + `swift-concurrency` — language-level guidance (auto-loaded for *.swift)
- `refactoring` — file-by-file approach, tier order, extract-don't-delete
- `design-system` — minimalistic aesthetic rules (auto-loaded for UI files)
- `git-flow` — branching + integration workflow (`/git-flow`)
- `save-context` — session preservation (`/save-context`)

## Knowledge graph

`graphify-out/` holds a committed code graph of this repo. Its node and community
counts are in `graphify-out/GRAPH_REPORT.md`, which also records the commit it was
built from — check that against `git rev-parse HEAD` before trusting it. Answer questions about architecture and file relationships from it before searching
the tree. Refresh it with `task graph:update` after any change that adds or deletes
files — a stale graph is worse than none. `graphify-out/GRAPH_REPORT.md` is the
human-readable summary; it is generated, so the markdown linter skips it.

Full architecture reference: [`Architecture.md`](Architecture.md), [`repo.yaml`](repo.yaml), [`AGENTS.md`](AGENTS.md), and [`CONTRIBUTING.md`](CONTRIBUTING.md)
App-local rules: [`Apps/machNotch/CLAUDE.md`](Apps/machNotch/CLAUDE.md)
