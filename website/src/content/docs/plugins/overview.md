---
title: Plugin SDK Overview
description: Build your own mach.notch plugins — protocol reference, lifecycle, and the capability model.
---

Every built-in feature of mach.notch — Music, Battery, Calendar, Shelf, Weather, Webcam — is a plugin. Third-party plugins use the same protocol and the same services.

The API described here is frozen. Members added after the freeze ship with a default implementation, so an existing plugin keeps compiling.

## Install

The SDK is the `NotchPluginCore` product. It holds the protocol, the context and the descriptor, and it depends on no plugin, so nothing about the built-ins leaks into yours.

```swift
dependencies: [
    .package(url: "https://github.com/larsboes/mach-mono", from: "1.4.0")
],
targets: [
    .target(
        name: "MyPlugin",
        dependencies: [
            .product(name: "NotchPluginCore", package: "mach-mono")
        ]
    )
]
```

A working template lives in [`examples/HelloPlugin`](https://github.com/larsboes/mach-mono/tree/main/examples/HelloPlugin). It builds with `swift build` and tests with `swift test`.

## The smallest legal plugin

Six members are required. Everything else has a default.

```swift
import NotchPluginCore
import Observation

@MainActor
@Observable
final class HelloPlugin: NotchPlugin {
    let id = "com.example.hello"
    let metadata = PluginMetadata(
        name: "Hello",
        description: "Shows a greeting in the expanded panel",
        icon: "hand.wave"
    )
    var isEnabled = false
    private(set) var state: PluginState = .inactive

    func activate(context: PluginContext) async throws {
        state = .active
    }

    func deactivate() async {
        state = .inactive
    }
}
```

## Required members

| Member | Type | Notes |
| --- | --- | --- |
| `id` | `String` | Reverse-DNS, stable across versions. It keys the plugin's settings. |
| `metadata` | `PluginMetadata` | Name, description, SF Symbol, version, author, category. |
| `isEnabled` | `Bool` | Read and written by the host. Do not act on it directly; use the lifecycle. |
| `state` | `PluginState` | `.inactive`, `.activating`, `.active`, `.error(PluginError)`. |
| `activate(context:)` | `async throws` | Set up observers and load data. Throwing marks the plugin failed. |
| `deactivate()` | `async` | Release everything `activate` acquired. |

## Optional members

Each has a default, so implement only what the plugin needs.

| Member | Default | Purpose |
| --- | --- | --- |
| `closedNotchContent()` | `EmptyView` | Compact view in the closed notch. |
| `expandedPanelContent()` | `EmptyView` | Full panel when the notch is open. |
| `settingsContent()` | `EmptyView` | Settings UI. Without it the host renders a plain toggle. |
| `menuBarView()` | `EmptyView` | Items in the menu bar dropdown. |
| `displayRequest` | `nil` | Ask to be shown in the closed notch. |

## Asking for screen time

Return a `DisplayRequest` to compete for the closed notch. The host resolves competing requests by priority.

```swift
var displayRequest: DisplayRequest? {
    guard hasSomethingToShow else { return nil }
    return DisplayRequest(priority: .high, category: .music)
}
```

`DisplayPriority` is ordered `.background` (0) < `.normal` (10) < `.high` (20) < `.critical` (30). `DisplayCategory` ships with `.music`, `.notification`, `.utility` and `.system`, and takes a custom string through `DisplayCategory(rawValue:)`.

## Extension points

Conform to any of these in addition to `NotchPlugin`. Each is defined in [`PluginCapabilities.swift`](https://github.com/larsboes/mach-mono/blob/main/Packages/NotchPlugins/Sources/NotchPlugins/Core/PluginCapabilities.swift).

| Protocol | Adds |
| --- | --- |
| `PlayablePlugin` | Transport controls — play, pause, skip, seek. |
| `ExportablePlugin` | Export the plugin's data in a declared `ExportFormat`. |
| `DataStoringPlugin` | Persist and load plugin data. |
| `DropReceivingPlugin` | Accept dropped items. |
| `NotifyingPlugin` | Publish notifications with a priority and actions. |
| `PositionedPlugin` | Pin closed-notch content to a `ClosedNotchPosition`. |

## Lifecycle

1. The host registers a `PluginDescriptor`. The plugin is **not** constructed yet.
2. The user enables the plugin. The host calls the descriptor's factory, then `activate(context:)`.
3. `deactivate()` runs on disable. The instance may be released afterwards.

Registration is metadata-only by design, so a disabled plugin costs nothing at launch. Keep the initializer cheap and do real work in `activate`.

## Next

- [PluginContext reference](/plugins/plugin-context) — services, settings, events, and the capability model.
- [Distribution](/plugins/distribution) — metadata, compatibility, and shipping a plugin.
