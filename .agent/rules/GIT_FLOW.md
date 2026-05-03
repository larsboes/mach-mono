---
description: "Git Branching and Deployment Constraints"
activation: "Always On"
---
# Git Flow Rule

To maintain the stability of `main`, follow these branching and merging constraints.

## Branching Strategy

| Branch | Role | Source | Rules |
|--------|------|--------|-------|
| `main` | Production / Stable | Topic Branches | Merge only verified topic branches. Build must be green. |
| `topic/` | Active Development | `main` | Naming: `feature/`, `fix/`, `perf/`, `refactor/`. |

## Development Rules

1. **Isolation:** All work happens in a topic branch.
2. **Build Integrity:** Run `/build` (if available) or verify compilation before merging into `main`.
3. **Documentation:** Every feature or performance fix must update `PRD.md` (Shipped section) and have a `walkthrough.md`.
4. **Resilience:** Use /git-flow to automate the integration process.
5. **Atomic Commits:** Prefer small, logical commits with descriptive messages.

## Deployment Flow

1. **Development:** Create branch from `main` → Implement → Verify.
2. **Integration:** Merge topic branch into `main` → Push to origin.
3. **Release:** Tag production-ready milestones from verified `main` commits.

@/docs/PRD.md
@/Users/larsboes/Developer/mach-mono/.agent/workflows/git-flow.md
