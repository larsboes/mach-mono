---
title: PluginContext Reference
description: Services, settings, events, and the capability model a plugin receives at activation.
---

`PluginContext` is the only handle a plugin gets to the host. It arrives as the argument to `activate(context:)` and carries everything the plugin is allowed to touch.

```swift
func activate(context: PluginContext) async throws {
    let music = context.mediaServices.music
    let refreshRate = context.settings.get("refreshRate", default: 30)

    cancellable = context.eventBus.subscribe(to: MusicTrackChangedEvent.self) { event in
        self.handle(event.newTrack)
    }

    state = .active
}
```

Hold the context only as long as the plugin is active, and drop the subscriptions in `deactivate()`.

`subscribe` returns an `AnyCancellable`, so a plugin that subscribes needs `import Combine`. The SDK does not re-export it.

## What the context carries

| Property | Type | Purpose |
| --- | --- | --- |
| `settings` | `PluginSettings` | Namespaced persistence for this plugin. |
| `eventBus` | `PluginEventBus` | Publish and subscribe to inter-plugin events. |
| `appState` | `any AppStateProviding` | App-wide state. Currently `isScreenLocked`. |
| `mediaSettings` | `any MediaSettings` | Shared media preferences — visualizer, live activity. |
| `grantedCapabilities` | `PluginCapabilities` | The service groups this plugin was granted. |

## The capability model

A plugin does not receive the full service container. It receives one facade per service group, and only for the groups its descriptor declared.

This is enforced, not advisory. Each accessor returns a type that conforms to exactly one sub-protocol, so a facade cannot be cast back up to reach services the plugin never asked for.

| Accessor | Capability to declare | Services |
| --- | --- | --- |
| `mediaServices` | `.mediaServices` | `music`, `lyrics`, `sound` |
| `systemServices` | `.systemServices` | `volume`, `brightness`, `keyboardBacklight`, `battery`, `systemStats`, `xpcHelper`, `fullScreen` |
| `storageServices` | `.storageServices` | `shelf`, `temporaryFileStorage`, `imageProcessing`, `thumbnails`, `shelfImageProcessor`, `shelfFileHandler`, `quickLook`, `quickShare` |
| `uiServices` | `.uiServices` | `notifications`, `systemNotificationObserver`, `sharing`, `dragDrop`, `webcam`, `face` |
| `pluginExtensionServices` | `.extensionServices` | `ai`, `aiEmbedding`, `bluetooth`, `bluetoothManager`, `notesManager`, `clipboardManager`, `calendar`, `weather`, `apiRouteRegistrar` |

Declare what the plugin needs on its descriptor:

```swift
PluginDescriptor(
    id: "com.example.hello",
    metadata: metadata,
    origin: .external("com.example.hello"),
    capabilities: [.mediaServices, .expandedPanelContent],
    factory: { HelloPlugin() }
)
```

Reaching for an undeclared group is a programming error. It traps on first access, which happens during activation, so it surfaces the first time the plugin is enabled rather than in the field.

Built-in plugins ship with the app and receive every group.

## Settings

`PluginSettings` namespaces every key under the plugin's `id`, so two plugins cannot collide and no plugin touches another's data. Reach for it instead of `UserDefaults` or `Defaults` directly.

```swift
context.settings.set("refreshRate", value: 60)
let rate = context.settings.get("refreshRate", default: 30)

if context.settings.exists("migratedV2") == false {
    migrate()
    context.settings.set("migratedV2", value: true)
}
```

`isEnabled`, `displayOrder` and `showInClosedNotch` are managed by the host. `remove(_:)` drops one key and `removeAll()` clears the namespace — call it when uninstalling.

## Events

`PluginEventBus` delivers synchronously on the main actor. Every `subscribe` returns an `AnyCancellable`; keeping it alive keeps the subscription alive.

```swift
// By event type
context.eventBus.subscribe(to: BatteryStateChangedEvent.self) { event in
    if event.isCharging { self.stopWarning() }
}

// By source plugin
context.eventBus.subscribe(from: "com.machnotch.music") { event in
    self.log(event)
}
```

Emit with `context.eventBus.emit(_:)`. Conform a `Sendable` struct to `PluginEvent` for a custom event, or use `GenericPluginEvent` for simple signals.

Prefer events over reaching into another plugin. Events are the supported way plugins talk to each other, and they keep working when the other plugin is disabled.

## Threading

`NotchPlugin`, `PluginContext` and every service protocol are `@MainActor`. Do async work in a `Task` and hop back before touching state:

```swift
func activate(context: PluginContext) async throws {
    state = .active
    task = Task {
        let result = await expensiveWork()
        self.value = result  // already on the main actor
    }
}

func deactivate() async {
    task?.cancel()
    cancellable = nil
    state = .inactive
}
```
