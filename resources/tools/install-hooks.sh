#!/bin/sh
# Point git at the committed .githooks/ directory so the skill-sync pre-commit
# hook (and any future shared hooks) run for this clone. Idempotent.
set -e

ROOT="$(git rev-parse --show-toplevel)"
git -C "$ROOT" config core.hooksPath .githooks
chmod +x "$ROOT/.githooks/"* 2>/dev/null || true

echo "Installed git hooks: core.hooksPath -> .githooks"
echo "Pre-commit will sync .claude/skills <-> .agents/skills via resources/tools/sync-skills.ts"
