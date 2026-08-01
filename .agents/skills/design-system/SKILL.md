---
name: "design-system"
description: "mach-mono visual design rules \u2014 minimalistic aesthetic, clarity, cohesion, tech-forward style, iconography. Auto-loaded when working on UI/view files."
---

# Design System: Minimalistic Aesthetic

> Full reference: `docs/AGENT-GUIDELINES.md` → Design System section.

All apps in this monorepo follow a strict **Minimalistic Aesthetic**.

## Core Principles

| Principle | Rule |
|---|---|
| **Clarity** | Every element must serve a functional purpose. Remove non-essential UI. |
| **Cohesion** | Consistent spacing, typography, and color across all apps. |
| **Tech-Forward** | Clean, modern, high-performance feel. No skeuomorphism. |
| **Subtlety** | Soft shadows, refined gradients, intentional color accents (neon-blue/purple) to guide attention. |

## Color

- Base palette: dark, sleek backgrounds
- Accents: neon-blue / purple — use intentionally, not decoratively
- No high-saturation colors for non-accent UI elements

## Typography

- System font stack — no custom fonts unless approved
- Consistent size scale — don't introduce arbitrary font sizes
- Prefer SF Symbols over bitmap icons

## Iconography

- Icons must be legible at 16×16
- Avoid excessive detail — favor abstract, geometric representations
- Consistent stroke weight across all icons in a feature
- Use SF Symbols wherever available before custom artwork

## Spacing

- Use consistent multiplies of the base spacing unit
- Avoid magic numbers — prefer named constants or SwiftUI's built-in spacing

## What "Minimalistic" Means Here

- One primary action per screen / panel
- Secondary actions are discoverable, not prominent
- Animations serve information (state changes), not decoration
- No loading spinners for operations < 200ms

## Codex Invocation

Use this skill for UI and view work. Codex does not enforce Claude `paths` or `user-invocable` metadata, so the file-scope trigger is preserved in the description.
