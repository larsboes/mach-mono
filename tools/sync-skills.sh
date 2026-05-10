#!/usr/bin/env bash
# Sync .claude/skills/ (source of truth) → .gemini/skills/ and .cursor/skills/.
# Run: task skills:sync
# CI:  called by the skills-check job to verify no drift.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${REPO_ROOT}/.claude/skills"
TARGETS=(".gemini/skills" ".cursor/skills")

if [ ! -d "${SRC}" ]; then
  echo "error: source directory ${SRC} not found" >&2
  exit 1
fi

SYNCED=0
for rel_target in "${TARGETS[@]}"; do
  dest="${REPO_ROOT}/${rel_target}"
  mkdir -p "${dest}"
  # Mirror: copy all skill dirs, remove any that no longer exist in source
  cp -r "${SRC}/." "${dest}/"
  SYNCED=$((SYNCED + 1))
  echo "  synced → ${rel_target}"
done

SKILL_COUNT=$(find "${SRC}" -name "SKILL.md" | wc -l | tr -d ' ')
echo "skills:sync — ${SKILL_COUNT} skill(s) mirrored to ${SYNCED} target(s)"
