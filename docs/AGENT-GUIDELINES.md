> **Skills are the operative layer.** Concise, actionable agent rules live in `.claude/skills/` (auto-synced to `.gemini/skills/` and `.cursor/skills/`). This file is the full human-readable reference — prose, diagrams, and code examples that skills distil from. When rules conflict, the skills take precedence.
>
> Run `task skills:sync` after editing any skill. Run `task skills:check` to verify sync.

# Agent Guidelines

> **Adapter note:** Canonical architecture docs live in `docs/Architecture.md`, and canonical repo facts live in `repo.yaml`. Keep this file as an agent-focused quick reference.

## Documentation Pointers

- **Architecture Details:** See [`docs/Architecture.md`](Architecture.md).
- **Feature Ideas & Concepts:** See [`Plans/PRDs/machNotch-ideas.md`](../Plans/PRDs/machNotch-ideas.md) and [`Plans/PRDs/machNotch.md`](../Plans/PRDs/machNotch.md).
- **Plugin Guide:** See [`docs/Guide.md`](Guide.md).

# Plugin Architecture Conventions

> **Adapter note:** Canonical repo facts live in `repo.yaml`; product and architecture details live in `Plans/PRDs/machNotch.md` and `docs/Architecture.md`. Keep this file as an agent-focused checklist.
>
> **Purpose:** Define the coding patterns and conventions for the plugin architecture to ensure consistency and avoid common pitfalls.

---

## 1. Settings Pattern (Dual Environment Keys)

**Problem:** We need protocol-based dependency injection for testing, but SwiftUI views often need concrete classes for `@Bindable` two-way bindings.

**Solution:** Use two separate environment keys.

### Implementation

```swift
// 1. Read-Only Key (Protocol)
// Use this for most views that just need to read settings.
// Testable with MockNotchSettings.
extension EnvironmentValues {
    var settings: any NotchSettings { get set }
}

// 2. Bindable Key (Concrete Class)
// Use this ONLY for settings views that need $settings bindings.
extension EnvironmentValues {
    var bindableSettings: DefaultsNotchSettings { get set }
}
```

### Usage Guidelines

**✅ DO:**

```swift
// Reading settings
struct UserProfileView: View {
    @Environment(\.settings) var settings // Protocol type
    
    var body: some View {
        if settings.showAvatar { ... }
    }
}

// Binding settings (Settings Views only)
struct GeneralSettingsView: View {
    @Environment(\.bindableSettings) var settings // Concrete type
    
    var body: some View {
        Toggle("Show Avatar", isOn: $settings.showAvatar)
    }
}
```

**❌ DON'T:**

- Don't use `@Environment(\.bindableSettings)` in standard views.
- Don't cast `settings` to `DefaultsNotchSettings`.

---

## 2. Service Protocols

**Principle:** Service protocols should mirror the *actual* manager APIs, not idealized interfaces.

**Rationale:** The goal is to wrap existing managers to enable DI, not to redesign the entire system at once.

**Guidelines:**

- **Match Properties:** If `MusicManager` has `playbackState`, `MusicServiceProtocol` must have `playbackState`.
- **Match Types:** Use the exact types defined in the codebase (e.g., `PlaybackState` struct, not a new enum).
- **Minimal Changes:** Don't add methods or properties that don't exist in the underlying manager yet.

---

## 3. AppStateProviding

**Principle:** Start minimal and expand incrementally.

**Rationale:** Avoiding "over-specifying" the protocol prevents build errors and implementation burden for properties that aren't actually used yet.

**Current MVP:**

```swift
protocol AppStateProviding: AnyObject {
    var isScreenLocked: Bool { get }
}
```

**Evolution:** Add properties (e.g., `isNotchExpanded`, `currentScreen`) only when a plugin specifically requires them.

---

## 4. MainActor Isolation

**Rule:** All UI-related protocols and classes must be `@MainActor`.

**Reasoning:**

- SwiftUI views are `@MainActor`.
- Environment objects are accessed from the main thread.
- `DefaultsNotchSettings` and Managers are stateful and interact with UI.

**Common Pitfall:**

- Environment key default values cannot synchronously instantiate `@MainActor` classes if the key itself isn't isolated.
- **Fix:** Use `nonisolated(unsafe)` for the default value if necessary, or ensure the type is thread-safe.

# Design System: Minimalistic Aesthetic

> **Adapter note:** Durable repo facts belong in `repo.yaml`; product-specific design scope belongs in the relevant PRD under `Plans/PRDs/`. Keep this file as a concise cross-app design checklist.

All applications within this monorepo must adhere to a strict **Minimalistic Aesthetic**.

## Core Principles

1. **Clarity:** Every element must serve a functional purpose. Remove non-essential UI.
2. **Cohesion:** Consistent use of spacing, typography, and color across all apps.
3. **Tech-Forward:** Design should be clean, modern, and high-performance.
4. **Subtlety:** Use soft shadows, refined gradients, and intentional color accents (neon-blue/purple) to guide attention.

## Iconography

- Icons must be legible at small sizes (16x16).
- Avoid excessive detail; favor abstract, geometric representations.
- Use a consistent, dark, sleek palette with vibrant accents.
