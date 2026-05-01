# Plugin Architecture Conventions

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
