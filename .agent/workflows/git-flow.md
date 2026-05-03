---
description: Standardized development workflow for machNotch
---

# /git-flow

This workflow guides you through the lifecycle of a feature or fix, from branch creation to integration into `main`.

## 1. Start Development
1. Ensure you are on the latest `main` branch.
// turbo
2. `git checkout main && git pull origin main`
3. Create a topic branch: `git checkout -b [type]/[name]` (e.g., `perf/phase3-opt`).

## 2. Implementation & Verification
1. Implement your changes following the [CONVENTIONS.md](file:///.agent/rules/CONVENTIONS.md).
2. Run `/build` to verify the project builds correctly.
3. Update `task.md` and `walkthrough.md` to document progress and proof-of-work.

## 3. Integration into Main
When work is complete and verified:
1. Commit your changes: `git add . && git commit -m "[type]: [description]"`
// turbo
2. `git checkout main && git pull origin main`
// turbo
3. `git merge [your-topic-branch]`
4. If there are conflicts, resolve them and commit.
// turbo
5. `git push origin main`

## 4. Cleanup (Optional)
If you prefer to keep your workspace clean after integration:
1. Delete the local topic branch: `git branch -d [topic-branch]` (Use `-d` for safe deletion)
2. Delete the remote topic branch: `git push origin --delete [topic-branch]`

## 5. Release
`main` is the release branch for this repo. Tag production-ready milestones from a verified `main` commit.
