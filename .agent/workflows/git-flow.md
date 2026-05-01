---
description: Standardized development workflow for boring.notch
---

# /git-flow

This workflow guides you through the lifecycle of a feature or fix, from branch creation to integration into the `developer` branch.

## 1. Start Development
1. Ensure you are on the latest `developer` branch.
// turbo
2. `git checkout developer && git pull origin developer`
3. Create a topic branch: `git checkout -b [type]/[name]` (e.g., `perf/phase3-opt`).

## 2. Implementation & Verification
1. Implement your changes following the [CONVENTIONS.md](file:///.agent/rules/CONVENTIONS.md).
2. Run `/build` to verify the project builds correctly.
3. Update `task.md` and `walkthrough.md` to document progress and proof-of-work.

## 3. Integration into Developer
When work is complete and verified:
1. Commit your changes: `git add . && git commit -m "[type]: [description]"`
// turbo
2. `git checkout developer && git pull origin developer`
// turbo
3. `git merge [your-topic-branch]`
4. If there are conflicts, resolve them and commit.
// turbo
5. `git push origin developer`

## 4. Cleanup (Optional)
If you prefer to keep your workspace clean after integration:
1. Delete the local topic branch: `git branch -d [topic-branch]` (Use `-d` for safe deletion)
2. Delete the remote topic branch: `git push origin --delete [topic-branch]`

## 4. Release to Main
(Reserved for production-ready milestones)
1. `git checkout main && git pull origin main`
2. `git merge developer`
3. `git push origin main`
