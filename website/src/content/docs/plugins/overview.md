---
title: Plugin SDK Overview
description: Build your own mach.notch plugins — architecture, protocol reference, and lifecycle.
---

:::caution[Coming Soon]
The Plugin SDK is in active development. Documentation will be published when the first public API is stable.
:::

## What's coming

The Plugin SDK will give third-party developers first-class access to the same APIs the built-in plugins use:

- **`NotchPlugin` protocol** — conformance, lifecycle (`activate` / `deactivate`), and UI slots
- **`PluginContext`** — dependency injection at activation time (services, event bus, settings)
- **`PluginEventBus`** — publish and subscribe to inter-plugin events
- **`PluginSettings`** — namespaced key-value persistence (no direct `Defaults` access needed)
- **Display priority** — control when your plugin surfaces in the notch

## Roadmap

- [ ] Stable `NotchPlugin` protocol freeze
- [ ] Public `PluginContext` API documentation
- [ ] Sample plugin template repository
- [ ] Distribution guidelines

Track progress on the [Roadmap](/roadmap).
