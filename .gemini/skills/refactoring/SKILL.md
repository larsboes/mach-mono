---
name: refactoring
description: mach-mono refactoring rules — file-by-file approach, dependency tier order, extract-don't-delete, build after each file, commit granularity.
user-invocable: false
---

# Refactoring Rules

> Full reference: `docs/AGENT-GUIDELINES.md` → Refactoring Rules.

## File-by-File Approach

Fix **all** violations in one pass when touching a file. Don't leave partial fixes:

1. Remove `.shared` singleton access
2. Replace direct `Defaults[.]` with settings injection
3. Split if > 300 lines
4. Add `@Observable` / `@MainActor` if missing

## Dependency Tier Order

Work tier-by-tier to avoid cascading breaks:

| Tier | Description | Approach |
|---|---|---|
| **1 — Leaf** | No downstream dependents | Safe to change first |
| **2 — Hub** | Consumed by Tier 1 | Change after Tier 1 is clean |
| **3 — God objects** | Decompose last | Break apart after tiers 1+2 stable |

## Extract, Don't Delete

When splitting large files:
1. Create new file with extracted code
2. Update imports in all consumers
3. Verify `bazelisk build //Apps/machNotch:machNotch` passes
4. **Then** remove from original

Never delete code without first verifying the replacement is working.

## Build After Every File

```bash
bazelisk build //Apps/machNotch:machNotch
```

Don't batch multiple files without verifying between them.

## Commit Granularity

One commit per logical unit — enables clean rollbacks:

```
refactor: eliminate .shared from VolumeManager   ✅
refactor: fix everything                         ❌
```

## Quick Checklist

- [ ] All violations in the file fixed (not partial)
- [ ] Extracted code in new file before removing from original
- [ ] Build passes after each file
- [ ] Commit is scoped to one logical unit
