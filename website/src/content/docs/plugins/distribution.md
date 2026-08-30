---
title: Distribution
description: Metadata, compatibility, signing and review expectations for shipping a mach.notch plugin.
---

A plugin ships as a Swift package that depends on `NotchPlugins` and vends a `PluginDescriptor`.

## Required metadata

`PluginMetadata` is what users see in Settings. All of it is required except `version`, `author` and `category`, which default.

| Field | Rule |
| --- | --- |
| `name` | Short. It appears in a list, not a title bar. |
| `description` | One sentence saying what the plugin does. |
| `icon` | An SF Symbol name that exists on the minimum supported macOS. |
| `version` | Semantic version. Bump it on every release. |
| `author` | Your name or organisation. |
| `category` | `.media`, `.productivity`, `.utilities`, `.system` or `.social`. |

The descriptor carries the rest:

```swift
public func makeDescriptor() -> PluginDescriptor {
    PluginDescriptor(
        id: "com.example.hello",
        metadata: metadata,
        origin: .external("com.example.hello"),
        capabilities: [.mediaServices, .expandedPanelContent, .settingsContent],
        factory: { HelloPlugin() }
    )
}
```

`origin` must be `.external(_:)`. `.builtIn` grants every service group and is reserved for plugins that ship with the app.

## Declare the narrowest capability set

`capabilities` is both a UI hint and a permission grant. List only what the plugin uses:

- UI slots — `.closedNotchContent`, `.expandedPanelContent`, `.settingsContent`, `.menuBarContent`, `.exportable`, `.positioned`
- Service groups — `.mediaServices`, `.systemServices`, `.storageServices`, `.uiServices`, `.extensionServices`

Over-declaring is visible to users and counts against a plugin in review. Under-declaring traps at activation, so it fails in your own testing first. See the [PluginContext reference](/plugins/plugin-context) for what each group contains.

## Identifier stability

`id` is permanent. It keys the plugin's settings namespace, its enabled state and its event subscriptions. Changing it orphans every user's configuration, so treat it as immutable once published.

## Compatibility

- The `NotchPlugin` surface is frozen. Members added later ship with a default implementation.
- Public enums — `PluginState`, `PluginError`, `PluginCategory`, `ExportFormat` — may gain cases in a minor release. Switch over them with an `@unknown default` or a `default` clause.
- Pin the `NotchPlugins` dependency to a major version.

## Testing expectations

Before publishing, confirm:

- The plugin activates and deactivates cleanly, repeatedly. Enable and disable it several times and watch for leaked observers.
- `deactivate()` releases every `AnyCancellable` and cancels every `Task` that `activate` started.
- The initializer is cheap. Registration builds the descriptor, not the plugin, and a slow initializer shows up as launch cost.
- Nothing is written outside the plugin's `PluginSettings` namespace or its own container.
- The plugin behaves when its declared services are unavailable — `bluetooth` and `apiRouteRegistrar` are optional and can be `nil`.

## Signing

Distribute the plugin signed with a Developer ID and notarized. An unsigned plugin is quarantined by Gatekeeper and will not load.

## Review criteria

A plugin submitted for listing is checked against:

- **Capability honesty** — declared capabilities match actual use.
- **Lifecycle correctness** — no work outside `activate`/`deactivate`, no retained context after deactivation.
- **No host internals** — the plugin builds against the public API only. Reaching into `@testable` or internal symbols is a rejection.
- **Settings hygiene** — writes stay inside the plugin's namespace.
- **Launch cost** — no measurable startup impact while disabled.

## Deprecation

Withdrawing a plugin means publishing a final version that calls `context.settings.removeAll()` on deactivation, so a user who disables it is not left with orphaned keys. Announce the withdrawal at least one minor release before the plugin stops receiving updates.
