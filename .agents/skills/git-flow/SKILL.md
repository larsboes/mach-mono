---
name: "git-flow"
description: "mach-mono git branching, integration, and release workflow \u2014 main as canonical branch, topic branches, commit shape, deploy via tags."
---

# Git Flow

> Full reference: `docs/AGENT-GUIDELINES.md` → Git Branching and Deployment Constraints.
> ADR: `docs/decisions/0001-main-only-branching.md`

## Branch Strategy

| Branch | Role | Rules |
|---|---|---|
| `main` | Canonical integration | Build must be green before push |
| `topic/` | Short-lived active dev | Naming: `feature/`, `fix/`, `perf/`, `refactor/` |

No long-lived `dev` branch. Work on `main` directly for small changes, topic branch for anything that takes more than one session.

## Start Development

```bash
git checkout main && git pull origin main
git checkout -b feature/my-feature   # or fix/, perf/, refactor/
```

## Implement & Verify

1. Implement changes following `.claude/skills/swift-code-quality` rules
2. `bazelisk build //Apps/machNotch:machNotch //Apps/machBrief:machBrief`
3. `bazelisk test //Apps/machNotch:machNotchTests //Packages/MachBriefKit:MachBriefKitTests`
4. Update relevant PRD under `Plans/PRDs/` and any affected ADRs

## Integrate into Main

```bash
git add <specific files>
git commit -m "type(scope): description"  # conventional commits
git checkout main && git pull origin main
git merge feature/my-feature              # or rebase for linear history
git push origin main
```

## Release

```bash
git tag v1.2.3
git push origin v1.2.3    # triggers release workflow
```

Tag format: `v<major>.<minor>.<patch>` or `v<version>-beta.<n>`.

## Commit Message Format

```
type(scope): short description (< 70 chars)

Optional body — WHY not WHAT. Reference issues if relevant.
```

Types: `feat`, `fix`, `chore`, `refactor`, `perf`, `test`, `docs`, `ci`

## Rules

- Build green before pushing to main
- No merge commits on main (repo rule enforced)
- Every feature/fix updates the relevant PRD + ADR if architecture changed
- Large cohesive solo-maintainer commits are acceptable when fully verified

## Codex Invocation

Use this skill when the user asks for `/git-flow` or explicitly requests the repository git workflow. Codex does not support Claude `argument-hint` or `disable-model-invocation` metadata, so treat any text after the skill name as plain user context.
