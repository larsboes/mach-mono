# Swift Code Quality Rules

Applies to: `**/*.swift`

## File Size Limits

**Hard limit: 300 lines** — Files exceeding this MUST be split.
**Target: 200 lines** — Prefer smaller, focused files.

When a file approaches 300 lines:
1. Identify cohesive responsibilities
2. Extract into separate files (e.g., `FooViewModel.swift` → `FooViewModel.swift` + `FooViewModelHelpers.swift`)
3. Use extensions in separate files for protocol conformances

## No Singletons in Views or Services

**BANNED patterns:**
```swift
// DON'T - singleton access
@Bindable var coordinator = BoringViewCoordinator.shared
let manager = SomeManager.shared
```

**REQUIRED patterns:**
```swift
// DO - environment injection
@Environment(BoringViewModel.self) private var viewModel
@Environment(\.pluginManager) private var pluginManager

// DO - init injection
init(service: SomeServiceProtocol) { ... }
```

## No Direct Defaults Access

**BANNED:**
```swift
Defaults[.someSetting]
@Default(.someSetting) var setting
```

**REQUIRED:**
```swift
// Use NotchSettings or PluginSettings abstraction
settings.someSetting
@Environment(\.bindableSettings) private var settings
```

Exception: `NotchSettings.swift` is the ONLY file allowed direct Defaults access.

## Observable State

**All observable classes MUST use:**
```swift
@Observable
@MainActor
final class SomeViewModel { ... }
```

**BANNED:**
```swift
class SomeViewModel: ObservableObject {
    @Published var state: State  // OLD pattern
}
```

## Protocol-Based Services

Services MUST be protocol-based for testability:
```swift
// Protocol in separate file
protocol SomeServiceProtocol: Sendable {
    func doThing() async throws
}

// Implementation
final class SomeService: SomeServiceProtocol { ... }
```

## File Organization

Standard order within files:
1. Imports
2. Type declaration with stored properties
3. Initializers
4. Public/internal methods
5. Private methods
6. Extensions (prefer separate files for large conformances)
