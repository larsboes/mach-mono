---
name: "plugin-architecture"
description: "machNotch plugin architecture rules \u2014 NotchPlugin protocol, lifecycle, DI via PluginContext, HUD event bus, PluginSettings. Auto-loaded when working in Plugins/."
---

# Plugin Architecture Rules

> Full reference: `docs/AGENT-GUIDELINES.md` → Plugin Architecture sections.

## Every Plugin Must

1. Conform to `NotchPlugin` protocol
2. Be `@Observable` and `@MainActor`
3. Receive all dependencies via `PluginContext` in `activate()`
4. Clean up all resources in `deactivate()`

```swift
@Observable
@MainActor
final class MyPlugin: NotchPlugin {
    let id = "com.machnotch.myplugin"
    private var services: ServiceContainer?

    func activate(context: PluginContext) async {
        self.services = context.services
    }

    func deactivate() async {
        self.services = nil
    }
}
```

## HUD / Sneak Peek

**Never** call coordinator methods directly. Always publish via event bus:

```swift
// ❌ DON'T
coordinator.showSneakPeek(.music)

// ✅ DO
PluginEventBus.shared.publish(SneakPeekRequestedEvent(type: .music))
```

## Service Access

Only via `PluginContext.services` — never import or access services directly:

```swift
func activate(context: PluginContext) async {
    let music = context.services.music
    let battery = context.services.battery
}
```

## Settings

Use namespaced `PluginSettings`. Never access `Defaults` directly:

```swift
let settings = PluginSettings(namespace: id)
settings.set("volume", value: 0.8)
let volume: Double = settings.get("volume", default: 1.0)
```

## Inter-Plugin Communication

Use `PluginEventBus` only. Plugins must **never** import each other:

```swift
// Publish
eventBus.emit(MusicPlaybackChangedEvent(isPlaying: true, track: track))

// Subscribe
eventBus.subscribe(to: CalendarEventStartingSoonEvent.self) { [weak self] event in
    await self?.handleUpcomingMeeting(event.event)
}
```

## Display Priority

Choose appropriate priority — don't default to `.high` or `.critical`:

| Priority | Use case |
|---|---|
| `.background` | Ambient info, yields to everything |
| `.normal` | Standard plugin content |
| `.high` | Time-sensitive (downloads, timers) |
| `.critical` | Errors, alerts — use sparingly |

## Settings Pattern: Dual Environment Keys

```swift
// ✅ Reading settings (most views)
@Environment(\.settings) var settings  // protocol type

// ✅ Binding settings (Settings Views only)
@Environment(\.bindableSettings) var settings  // concrete type for $bindings

// ❌ Don't use bindableSettings outside Settings views
// ❌ Don't cast settings to DefaultsNotchSettings
```

## New Plugin Checklist

- [ ] Conforms to `NotchPlugin`
- [ ] `@Observable @MainActor final class`
- [ ] `activate(context:)` wires services; `deactivate()` nils them
- [ ] HUD requests via `PluginEventBus`, not direct coordinator calls
- [ ] Settings via `PluginSettings(namespace: id)`, not `Defaults`
- [ ] No imports of sibling plugins
- [ ] Protocol added to `ServiceContainer` if new service needed

## Codex Invocation

Use this skill for work in plugin-related Swift files. Codex does not enforce Claude `paths` or `user-invocable` metadata, so the file-scope trigger is preserved in the description.
