# Skills Usage Rule

> **Purpose:** Ensure available skills are checked and used when working on plans and tasks.

---

## When Working on Plans

Before executing any implementation plan:

1. **Check available skills** in `.agent/skills/` directory
2. **Read the SKILL.md** file for any relevant skill
3. **Follow the skill's instructions** exactly as documented

## Available Skills

| Skill | When to Use |
|-------|-------------|
| `swift-concurrency` | Any work involving async/await, actors, @MainActor, Sendable, or Swift 6 migration |
| `save-context` | Before ending a conversation, to preserve progress for future sessions |

## Skill Activation

Skills are activated by reading their `SKILL.md` file. When a plan references patterns covered by a skill (e.g., "use event bus" or "migrate to @Observable"), check if a relevant skill exists first.

## Plan Integration

Plans in `docs/plans/` may reference skills via:
- `> **For Claude:** Use superpowers:executing-plans to implement this plan`
- Skill-specific patterns (e.g., `@MainActor`, `PluginEventBus`)

Always cross-reference plan requirements with available skills before implementation.
