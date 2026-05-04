# 0001 — Main-only branching

- Status: Accepted
- Date: 2026-05-04

## Context

`mach-mono` is currently a solo-maintained repository. Maintaining long-lived integration branches adds coordination overhead and increases the chance that docs, CI, and product status drift from the actual shippable state.

## Decision

Use a `main`-only branch model unless maintainers explicitly introduce another branch later.

Short-lived local or remote topic branches are fine for isolated work, but `main` remains the canonical integration branch.

## Consequences

- Documentation, CI, and release notes should describe `main` as the default branch.
- Agent workflows should not require a `dev` branch.
- Larger solo-maintainer commits are acceptable when they keep the repo coherent and verified.
- If a multi-maintainer workflow emerges, this decision should be revisited.
