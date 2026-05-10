# Project Guidelines

Agent skills live in **`.claude/skills/`** (source of truth) and define all operative coding rules:

- `plugin-architecture` — plugin protocol, lifecycle, DI, HUD events (auto-loaded for Plugins/)
- `swift-code-quality` — file limits, @Observable, no singletons, no direct Defaults (auto-loaded for *.swift)
- `swift` + `swift-concurrency` — language-level guidance (auto-loaded for *.swift)
- `refactoring` — file-by-file approach, tier order, extract-don't-delete
- `design-system` — minimalistic aesthetic rules (auto-loaded for UI files)
- `git-flow` — branching + integration workflow (`/git-flow`)
- `save-context` — session preservation (`/save-context`)

Full architecture reference: [`docs/AGENT-GUIDELINES.md`](docs/AGENT-GUIDELINES.md)
App-local rules: [`Apps/machNotch/CLAUDE.md`](Apps/machNotch/CLAUDE.md)
