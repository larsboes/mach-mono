# mach-mono — Project Instructions

## Overview
Monorepo of focused macOS quality-of-life utilities. Named after the Mach microkernel that powers macOS.

## Structure
```
mach-mono/
├── .agent/              # Agent workflows and skills
├── .claude/             # Claude Code rules
├── .github/             # CI/CD workflows, issue templates
├── Apps/
│   └── machNotch/       # Notch utility (mach.notch) — see Apps/machNotch/CLAUDE.md
├── docs/
│   ├── PRD.md           # Active implementation plan + feature roadmap + debt triage
│   ├── ARCHITECTURE.md  # System architecture reference
│   └── PLUGIN_DEVELOPMENT.md
├── Packages/            # Shared Swift packages (empty until second app)
├── resources/           # Demo assets, notchctl script
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
└── mach-mono.xcworkspace
```

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
