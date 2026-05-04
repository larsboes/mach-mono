# mach-mono — Project Instructions

## Overview
Monorepo of focused Apple platform quality-of-life utilities — macOS and iOS. Named after the Mach microkernel that powers macOS.

## Structure
```
mach-mono/
├── .agent/              # Agent workflows and skills
├── .claude/             # Claude Code rules
├── .github/             # CI/CD workflows, issue templates
├── Apps/
│   ├── machNotch/       # macOS notch utility (mach.notch) — see Apps/machNotch/CLAUDE.md
│   └── machBrief/       # iOS daily content app (mach.brief) — see docs/machBrief-PRD.md [planned]
├── docs/
│   ├── PRD.md               # machNotch implementation plan + feature roadmap + debt triage
│   ├── machBrief-PRD.md     # machBrief product spec (iOS + shared package, sources/sinks model)
│   ├── SIDELOADING.md       # Free Apple ID sideloading guide (no $99/yr needed for personal use)
│   ├── ARCHITECTURE.md      # System architecture reference
│   └── PLUGIN_DEVELOPMENT.md
├── Packages/
│   └── MachBriefKit/    # Shared Swift package — sources, sinks, scheduler, store [planned]
├── resources/           # Demo assets, notchctl script
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
└── mach-mono.xcworkspace
```

## License

| Component | Current | Target | Notes |
|-----------|---------|--------|-------|
| `Apps/machNotch/` | GPL v3 | MIT | Inherited from BoringNotch fork. Requires file-by-file reengineering — see `docs/PRD.md → License Migration` |
| `Apps/machBrief/` | — | MIT | New app, clean slate |
| `Packages/MachBriefKit/` | — | MIT | New package, clean slate |
| `Packages/MacroVisionKit/` | MIT | MIT | Already clean |
| Root `/LICENSE` | GPL v3 | MIT | Update last, after machNotch is clean |

**Rule for new apps and packages:** MIT from creation. No GPL or MPL dependencies allowed.
**Rule for machNotch plugins** inspired by GPL projects: independent reimplementation only — document the `License note:` in the PRD spec and write zero lines from the reference project.

## Working in this repo
- Each app has its own `CLAUDE.md` with build/test instructions
- Shared packages (when added) live in `Packages/` as local SPM packages
- Root commits: structural changes, README, LICENSE, workspace config only
- App commits: always `cd Apps/<app>` and follow that app's CLAUDE.md

## Adding a new app
1. Create `Apps/<appName>/` with a new Xcode project
2. Add a `CLAUDE.md` inside it
3. Wire into `mach-mono.xcworkspace` (create workspace if this is the second app)
4. Add a `Packages/MachCore` or `Packages/MachUI` entry if shared code is needed
