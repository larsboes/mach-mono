# resources/tools

## Skill sync — Claude Code ⇄ Antigravity

`sync-skills.ts` keeps agent skills mirrored between the two platforms:

| Side | Path | Frontmatter |
|------|------|-------------|
| Claude Code | `.claude/skills/<name>/SKILL.md` | superset (`name`, `description`, `paths`, `user-invocable`, `argument-hint`, `disable-model-invocation`, comments) |
| Antigravity | `.agents/skills/<name>/SKILL.md` | projection (`name` + `description` only) |

**Edit either side.** On the next commit the change is mirrored to the other side:

- **Claude → Antigravity** emits a clean `name`+`description` projection; the body is copied verbatim.
- **Antigravity → Claude** is a *merge*: only `name`/`description`/body are updated; every Claude-only field is preserved.

### How it decides direction

A committed state file (`skill-sync-state.json`) stores each skill's shared-content hash
(name + description + body; comments and extra frontmatter excluded). Per skill:

- only one side changed since last sync → that side is the source
- **both** changed → newer `SKILL.md` mtime wins
- neither changed → skip
- exists on one side only → created on the other (bootstrap)

Skill *deletion* is intentionally not propagated.

### Usage

```sh
bun resources/tools/sync-skills.ts            # sync now
bun resources/tools/sync-skills.ts --dry-run  # preview, write nothing
sh resources/tools/install-hooks.sh           # wire the pre-commit hook (core.hooksPath -> .githooks)
```

The pre-commit hook (`.githooks/pre-commit`) runs the sync and re-stages the result automatically.
New clones run `sh resources/tools/install-hooks.sh` once to activate it.

## Agent hooks — Antigravity ⇄ Claude Code

Both agents run the same `resources/tools/hooks/*.ts` (dual-protocol: each detects the
platform from the stdin payload). Config lives in two files: `.agents/hooks.json`
(Antigravity) and the `hooks` block of `.claude/settings.json` (Claude Code).

| # | Hook | Event | Does | Platforms |
|---|------|-------|------|-----------|
| 1 | skill mirror | `PostToolUse` (file writes) | runs `sync-skills.ts` so skill edits mirror live mid-session, not just at commit | both |
| 2 | command gate | `PreToolUse` (commands) | `command-gate.ts` denies `xcodebuild` / `npm`/`npx`/`yarn`/`pnpm` with a reason; everything else allowed | both |
| 3 | swift arch-check | `PostToolUse` (`*.swift` write) | `swift-archcheck.ts` runs `arch-check.sh`, feeds violations back | Claude only¹ |
| 4 | green-gate | `Stop` | `stop-gate.ts` runs `arch-check.sh`, refuses to finish while violations exist | both |

¹ Antigravity's `PostToolUse` returns `{}` (no feedback channel and no tool args),
so the Swift check is enforced there via the Stop green-gate (#4) instead.

**Loop-safety:** the green-gate intervenes at most once per run — Claude honors
`stop_hook_active`; Antigravity bails when `fullyIdle` is false or `executionNum >= 2`
— so a failing check can never lock an agent in a stop→continue loop.

The command blocklist is a `BLOCKLIST` array at the top of `command-gate.ts`; edit
there to adjust. Claude project hooks load on session start (restart Claude Code to
pick up changes); Antigravity reads `.agents/hooks.json` from the workspace.
