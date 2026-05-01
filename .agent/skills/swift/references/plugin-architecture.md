# Plugin Architecture Patterns

Reference for designing and implementing plugin systems in Swift/macOS apps.

## Core Concepts

### Plugin Protocol
The contract that all plugins must implement:

```swift
@MainActor
protocol Plugin: Identifiable, Observable, AnyObject {
    var id: String { get }
    var isEnabled: Bool { get set }
    
    func activate(context: PluginContext) async throws
    func deactivate() async
}
```

Key design decisions:
- `@MainActor` — UI-bound plugins run on main thread
- `Observable` — SwiftUI can observe plugin state changes
- `AnyObject` — Plugins are reference types (shared state)
- `async throws` — Activation can fail and may be async

### Plugin Manager
Central registry managing plugin lifecycle:

```swift
@MainActor
@Observable
final class PluginManager {
    private var plugins: [String: AnyPlugin] = [:]
    
    func register(_ plugin: any Plugin) {
        plugins[plugin.id] = AnyPlugin(plugin)
    }
    
    func activate(_ id: String) async throws {
        guard let plugin = plugins[id] else { return }
        let context = PluginContext(...)
        try await plugin.activate(context: context)
    }
}
```

### Plugin Context
Dependency injection container passed to plugins:

```swift
struct PluginContext {
    let settings: PluginSettings
    let services: ServiceContainer
    let eventBus: PluginEventBus
    let appState: AppStateProviding
}
```

## Type Erasure

When protocols have `@ViewBuilder` or associated types:

```swift
@MainActor
struct AnyPlugin: Identifiable {
    let id: String
    private let _closedContent: () -> AnyView?
    
    init<P: Plugin>(_ plugin: P) {
        self.id = plugin.id
        self._closedContent = { plugin.closedContent() }
    }
    
    func closedContent() -> AnyView? { _closedContent() }
}
```

## Event Bus

Loose coupling between plugins:

```swift
final class PluginEventBus: @unchecked Sendable {
    private let lock = NSLock()
    private var handlers: [EventType: [(PluginEvent) -> Void]] = [:]
    
    func on(_ type: EventType, handler: @escaping (PluginEvent) -> Void) {
        lock.lock()
        handlers[type, default: []].append(handler)
        lock.unlock()
    }
    
    func emit(_ type: EventType, from: String, payload: Any? = nil) {
        let event = PluginEvent(type: type, source: from, payload: payload)
        lock.lock()
        let handlers = handlers[type, default: []]
        lock.unlock()
        handlers.forEach { $0(event) }
    }
}
```

## Plugin State Machine

```swift
enum PluginState: Equatable, Sendable {
    case inactive
    case activating
    case active
    case error(PluginError)
    
    var isActive: Bool {
        if case .active = self { return true }
        return false
    }
}
```

## Best Practices

1. **No singleton access** — Everything comes through PluginContext
2. **Async activation** — Plugins may need to load resources
3. **Graceful degradation** — One plugin failure shouldn't crash others
4. **Type-safe events** — Use enums for event types, not strings
5. **Resource cleanup** — Always implement deactivate()
