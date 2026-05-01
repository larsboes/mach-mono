---
description: "Git Branching and Deployment Constraints"
activation: "Always On"
---
# Git Flow Rule

To maintain the stability of `main` and the integrity of `developer`, follow these branching and merging constraints.

## Branching Strategy

| Branch | Role | Source | Rules |
|--------|------|--------|-------|
| `main` | Production / Stable | `developer` | Never commit directly. Requires verified merge from `developer`. |
| `developer` | Integration / Next Release | Topic Branches | Fast-forward or squash merges only. Build must be green. |
| `topic/` | Active Development | `developer` | Naming: `feature/`, `fix/`, `perf/`, `refactor/`. |

## Development Rules

1. **Isolation:** All work happens in a topic branch.
2. **Build Integrity:** Run `/build` (if available) or verify compilation before merging into `developer`.
3. **Documentation:** Every feature or performance fix must update `PRD.md` (Shipped section) and have a `walkthrough.md`.
4. **Resilience:** Use /git-flow to automate the integration process.
5. **Atomic Commits:** Prefer small, logical commits with descriptive messages.

## Deployment Flow

1. **Development:** Create branch from `developer` → Implement → Verify.
2. **Integration:** Merge topic branch into `developer` → Push to origin.
3. **Release:** Periodic merge from `developer` to `main` for public distribution.

@/docs/PRD.md
@/Users/larsboes/Developer/boring.notch/.agent/workflows/git-flow.md
