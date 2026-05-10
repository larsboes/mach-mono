---
name: swift-code-quality
description: Swift code quality rules for mach-mono — 300-line file limit, @Observable, no singletons in views, no direct Defaults access, protocol-based services. Auto-loaded when editing .swift files.
user-invocable: false
paths: "**/*.swift"
---

# Swift Code Quality Rules

> Full reference: `docs/AGENT-GUIDELINES.md` → Swift Code Quality Rules.

## File Size

| Limit | Rule |
|---|---|
| **300 lines** | Hard limit — files exceeding this **must** be split |
| **200 lines** | Target — prefer smaller, focused files |

When approaching 300 lines: extract cohesive responsibilities into separate files, use extensions in separate files for protocol conformances.

## No Singletons in Views or Services

```swift
// ❌ BANNED
@Bindable var coordinator = NotchViewCoordinator.shared
let manager = SomeManager.shared

// ✅ REQUIRED — environment injection
@Environment(NotchViewModel.self) private var viewModel
@Environment(\.pluginManager) private var pluginManager

// ✅ REQUIRED — init injection
init(service: SomeServiceProtocol) { ... }
```

**Allowed `.shared` exceptions:** `NSWorkspace`, `NSApplication`, `URLSession`, `URLCache`, `XPCHelperClient`, `FullScreenMonitor`, `QLThumbnailGenerator`, `QLPreviewPanel`, `NSScreenUUIDCache`, `SkyLightOperator`, `DefaultsNotchSettings` (injection root only).

## No Direct Defaults Access

```swift
// ❌ BANNED everywhere except NotchSettings.swift
Defaults[.someSetting]
@Default(.someSetting) var setting

// ✅ REQUIRED
settings.someSetting
@Environment(\.bindableSettings) private var settings
```

**Exception:** `NotchSettings.swift` is the **only** file allowed direct `Defaults` access.

## Observable State

```swift
// ✅ REQUIRED
@Observable
@MainActor
final class SomeViewModel { ... }

// ❌ BANNED
class SomeViewModel: ObservableObject {
    @Published var state: State
}
```

All UI-related protocols and classes must be `@MainActor`.

## Protocol-Based Services

```swift
// Protocol in separate file
protocol SomeServiceProtocol: Sendable {
    func doThing() async throws
}

// Implementation
final class SomeService: SomeServiceProtocol { ... }
```

Never depend on concrete service types — always use the protocol.

## File Organization Order

1. Imports
2. Type declaration + stored properties
3. Initializers
4. Public/internal methods
5. Private methods
6. Extensions (prefer separate files for large protocol conformances)

## Commit Checklist Before Submitting Swift Changes

- [ ] File stays under 300 lines (if split, both files build)
- [ ] No new `.shared` access in views or services
- [ ] No new direct `Defaults[.]` outside NotchSettings.swift
- [ ] New state classes use `@Observable @MainActor final class`
- [ ] New services have a protocol
- [ ] `bazelisk build //Apps/machNotch:machNotch` passes
