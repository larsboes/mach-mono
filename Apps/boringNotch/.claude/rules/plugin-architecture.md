# Plugin Architecture Rules

Applies to: `**/Plugins/**/*.swift`

## Plugin Structure

Every plugin MUST:
1. Conform to `NotchPlugin` protocol
2. Be `@Observable` and `@MainActor`
3. Receive dependencies via `PluginContext` in `activate()`
4. Clean up resources in `deactivate()`

```swift
@Observable
@MainActor
final class MyPlugin: NotchPlugin {
    let id = "com.boringnotch.myplugin"
    let name = "My Plugin"

    private var services: ServiceContainer?

    func activate(context: PluginContext) async {
        self.services = context.services
    }

    func deactivate() async {
        self.services = nil
    }
}
```

## HUD/Sneak Peek Requests

**NEVER** call coordinator methods directly. Use the event bus:

```swift
// DON'T
coordinator.showSneakPeek(.music)

// DO
PluginEventBus.shared.publish(SneakPeekRequestedEvent(type: .music))
```

## Service Access

Plugins access services ONLY through `PluginContext.services`:

```swift
func activate(context: PluginContext) async {
    let music = context.services.music
    let battery = context.services.battery
}
```

## Plugin Settings

Use namespaced `PluginSettings`, never raw Defaults:

```swift
let settings = PluginSettings(namespace: id)
settings.set("volume", value: 0.8)
let volume: Double = settings.get("volume", default: 1.0)
```

## Display Priority

Choose appropriate priority for your content:
- `.background` — ambient info, yields to everything
- `.normal` — standard content
- `.high` — time-sensitive (downloads, timers)
- `.critical` — alerts, errors (use sparingly)
