# Refactoring Rules

Applies to: all files during refactoring work

## File-by-File Approach

When refactoring a file, fix ALL violations in one pass:
1. Remove `.shared` singleton access
2. Replace direct `Defaults[.]` with settings injection
3. Split if > 300 lines
4. Add `@Observable` / `@MainActor` if missing

Don't leave partial fixes — each file should be clean when you're done.

## Dependency Order

Work in tier order to avoid breaking changes:

1. **Tier 1 (Leaf files)** — No downstream dependents, safe to change
2. **Tier 2 (Hub files)** — Change after Tier 1 consumers are clean
3. **Tier 3 (God objects)** — Decompose last

## Extract, Don't Delete

When splitting large files:
1. Create new file with extracted code
2. Update imports in consumers
3. Verify build passes
4. THEN remove from original

## Test After Each File

After completing a file:
```bash
xcodebuild -scheme boringNotch -destination 'platform=macOS' build 2>&1 | tail -50
```

Don't batch multiple files without verifying builds.

## Commit Granularity

One commit per logical unit:
- "refactor: eliminate .shared from VolumeManager" ✓
- "refactor: fix everything" ✗

This makes rollbacks possible if something breaks.
