---
name: swift
description: "Use when working with Swift code, especially macOS SwiftUI apps with modern concurrency, plugin architectures, and dependency injection. Covers @MainActor, @Observable, structured concurrency, protocol-based design, and Swift 6 migration."
# @sync: public
---

# Swift for macOS Development

Expert guidance for Swift development on Apple platforms, with focus on modern Swift patterns, macOS SwiftUI, plugin architectures, and strict concurrency.

## When to Use

- Building or refactoring macOS/iOS apps with SwiftUI
- Working with plugin-based architectures (like boring.notch)
- Implementing dependency injection without singletons
- Swift 6 migration and strict concurrency issues
- Modern concurrency patterns (async/await, actors, Sendable)
- @Observable migration from ObservableObject
- @MainActor isolation and UI threading

## Agent Behavior Contract

1. **Check Swift version first** — Look at `Package.swift` tools version or Xcode project settings before giving version-specific advice
2. **Prefer modern patterns** — `@Observable` over `ObservableObject`, protocol-based DI over `.shared` singletons
3. **Respect @MainActor** — UI code must be `@MainActor`; don't suggest `@MainActor` as blanket fix for non-UI code
4. **Strict concurrency aware** — Assume Swift 6 complete checking; justify any `@preconcurrency` or `@unchecked Sendable`
5. **Type-erasure when needed** — Use `AnyView` or custom existential wrappers for protocol types with associated types

## Quick Decision Tree

### Starting a new file?
1. Check existing patterns in sibling files first
2. Max 300 lines per file (hard limit)
3. Use `@Observable` + `@MainActor` for state
4. Protocol-based services, injected via init

### Refactoring legacy code?
1. **Eliminate singletons first** — Replace `.shared` with injected protocols
2. **Migrate to @Observable** — Replace `ObservableObject`/`@Published` with `@Observable`
3. **Add @MainActor** — UI-related classes only
4. **Fix concurrency** — Make types `Sendable`, use actors for shared state

### Plugin architecture?
1. Read `NotchPlugin` protocol definition
2. Plugin receives `PluginContext` via `activate(context:)`
3. Never access `Defaults[.]` directly — use settings wrappers
4. Use `PluginEventBus` for cross-plugin communication

## Core Patterns

### Plugin Protocol Design
```swift
@MainActor
protocol NotchPlugin: Identifiable, Observable, AnyObject {
    var id: String { get }
    var metadata: PluginMetadata { get }
    var isEnabled: Bool { get set }
    var state: PluginState { get }
    
    func activate(context: PluginContext) async throws
    func deactivate() async
    
    @ViewBuilder
    func closedNotchContent() -> AnyView?
}
```

### Dependency Injection (No Singletons)
```swift
// ❌ Don't: Singleton access
class MyView: View {
    @StateObject private var vm = BoringViewModel.shared
}

// ✅ Do: Injected via init or environment
struct MyView: View {
    @Environment(\.serviceContainer) private var services
    let viewModel: MyViewModel  // Injected
    
    init(viewModel: MyViewModel) {
        self.viewModel = viewModel
    }
}
```

### @Observable + @MainActor
```swift
// ❌ Don't: ObservableObject
@MainActor
class OldViewModel: ObservableObject {
    @Published var data: String = ""
}

// ✅ Do: @Observable
@MainActor
@Observable
final class NewViewModel {
    var data: String = ""
    private let service: DataService
    
    init(service: DataService) {
        self.service = service
    }
}
```

### Service Protocol Pattern
```swift
protocol DataService: Sendable {
    func fetch() async throws -> Data
}

@MainActor
final class DataServiceImpl: DataService {
    func fetch() async throws -> Data {
        // Implementation
    }
}
```

### Type Erasure for Protocols
```swift
// When protocol has associated types or @ViewBuilder
@MainActor
struct AnyNotchPlugin: Identifiable {
    let id: String
    private let _activate: (PluginContext) async throws -> Void
    
    init<P: NotchPlugin>(_ plugin: P) {
        self.id = plugin.id
        self._activate = { try await plugin.activate(context: $0) }
    }
    
    func activate(context: PluginContext) async throws {
        try await _activate(context)
    }
}
```

## Swift 6 Concurrency Patterns

### Sendable Conformance
```swift
// Value types: automatic
struct Config: Sendable {
    let name: String
    let value: Int
}

// Reference types: explicit conformance
final class Cache: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    
    func get(_ key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }
}
```

### Actor Isolation
```swift
// Shared mutable state → actor
actor DataStore {
    private var items: [Item] = []
    
    func add(_ item: Item) {
        items.append(item)
    }
    
    func allItems() -> [Item] {
        items
    }
}

// Access from outside
let store = DataStore()
await store.add(newItem)
let items = await store.allItems()
```

### MainActor for UI
```swift
@MainActor
final class ViewModel {
    var text: String = ""
    
    func updateFromBackground() async {
        let result = await backgroundTask()
        // Already on MainActor, can update UI
        self.text = result
    }
}
```

## macOS SwiftUI Specifics

### Window Management
```swift
// Control window behavior
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)  // No title bar
        .windowResizability(.contentSize)  // Fixed size
    }
}
```

### MenuBar Extra
```swift
MenuBarExtra("App", systemImage: "icon") {
    ContentView()
}
.menuBarExtraStyle(.window)
```

### NSView Integration
```swift
struct NativeView: NSViewRepresentable {
    func makeNSView(context: Context) -> SomeNSView {
        let view = SomeNSView()
        return view
    }
    
    func updateNSView(_ nsView: SomeNSView, context: Context) {}
}
```

## Common Refactoring Patterns

### Eliminating Singletons
1. **Extract protocol** from the singleton class
2. **Create implementation** conforming to protocol
3. **Inject via init** or environment
4. **Update all call sites** — find with grep: `\.shared`

### Settings Access Pattern
```swift
// ❌ Don't: Direct Defaults access
Defaults[.showIcon] = true

// ✅ Do: Wrapped settings
@MainActor
final class NotchSettings {
    var showIcon: Bool {
        get { Defaults[.showIcon] }
        set { Defaults[.showIcon] = newValue }
    }
}

// Access via environment
@Environment(\.settings) private var settings
```

### Event Bus Communication
```swift
// Publish event
PluginEventBus.shared.emit(.sneakPeekRequested, from: pluginId, payload: data)

// Subscribe to events
eventBus.on(.sneakPeekRequested) { event in
    // Handle event
}
```

## LSP Integration (On-Demand)

Use the bundled LSP script for code intelligence when needed. Requires `npx` (comes with Node.js) — tsx will be auto-installed on first run.

```bash
# Check status and workspace info
~/.pi/skills/swift/scripts/lsp.ts status

# Go to definition (1-indexed line:column)
~/.pi/skills/swift/scripts/lsp.ts goto ./MyFile.swift 42 15

# Get hover info/type docs
~/.pi/skills/swift/scripts/lsp.ts hover ./MyFile.swift 42 15
```

The LSP client auto-detects:
- SourceKit-LSP location (Xcode, Homebrew, system)
- Workspace root (Package.swift or .xcodeproj)
- Swift files in the project

**Note:** First run installs `tsx` via npx (may take 10-15s). Subsequent runs are instant.

## Build & Debug

### Build Command
```bash
xcodebuild -scheme boringNotch -destination 'platform=macOS' build 2>&1 | tail -50
```

### Test Command
```bash
xcodebuild -scheme boringNotch -destination 'platform=macOS' test 2>&1 | tail -50
```

### Common Build Errors

| Error | Likely Cause | Fix |
|-------|--------------|-----|
| `Cannot find 'X' in scope` | Missing import or deleted file | Check imports, file targets |
| `Cannot convert value of type` | Type mismatch in async context | Add `await`, check isolation |
| `Call can throw, but...` | Missing try/await | Add `try await` |
| `Main actor-isolated...` | Accessing @MainActor from non-isolated | Move to @MainActor context |
| `Sending 'X' risks causing data races` | Non-Sendable crossing isolation | Make Sendable or use actor |

## References

- [swift-concurrency](skill:swift-concurrency) — Deep dive on async/await, actors, Sendable
- [swift-ui-performance](references/swift-ui-performance.md) — Rendering optimization
- [macos-windowing](references/macos-windowing.md) — Window management patterns
- [plugin-architecture](references/plugin-architecture.md) — Plugin system design
- [dependency-injection](references/dependency-injection.md) — DI patterns for Swift

## Verification Checklist

Before claiming a Swift refactor is complete:

- [ ] Build passes with no warnings
- [ ] No `.shared` singletons remain
- [ ] No direct `Defaults[.]` access outside settings wrappers
- [ ] All UI classes marked `@MainActor`
- [ ] File length ≤ 300 lines
- [ ] Protocol-based services injected via init
- [ ] `@Observable` used instead of `ObservableObject`
