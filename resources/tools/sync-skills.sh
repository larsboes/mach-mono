#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: resources/tools/sync-skills.sh [--check|--dry-run]

Ensures .cursor/skills and .gemini/skills point at the canonical
.claude/skills tree.
EOF
}

MODE="sync"
if [ "${1:-}" = "--check" ]; then
    MODE="check"
elif [ "${1:-}" = "--dry-run" ]; then
    MODE="dry-run"
elif [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
elif [ "${1:-}" != "" ]; then
    usage >&2
    exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/.claude/skills"

if [ ! -d "$SOURCE" ]; then
    echo "error: canonical skills directory not found: $SOURCE" >&2
    exit 1
fi

ensure_link() {
    local target_dir="$1"
    local link_path="$target_dir/skills"
    local link_target="../.claude/skills"

    if [ "$MODE" = "sync" ]; then
        mkdir -p "$target_dir"
    elif [ ! -d "$target_dir" ]; then
        echo "error: target directory missing: ${target_dir#$ROOT/}" >&2
        return 1
    fi

    if [ -L "$link_path" ]; then
        local current
        current="$(readlink "$link_path")"
        if [ "$current" = "$link_target" ]; then
            echo "ok: ${link_path#$ROOT/} -> $current"
            return 0
        fi
    fi

    if [ "$MODE" = "check" ]; then
        echo "error: ${link_path#$ROOT/} must be a symlink to $link_target" >&2
        return 1
    fi

    if [ "$MODE" = "dry-run" ]; then
        echo "would link: ${link_path#$ROOT/} -> $link_target"
        return 0
    fi

    rm -rf "$link_path"
    ln -s "$link_target" "$link_path"
    echo "linked: ${link_path#$ROOT/} -> $link_target"
}

ensure_link "$ROOT/.cursor"
ensure_link "$ROOT/.gemini"
