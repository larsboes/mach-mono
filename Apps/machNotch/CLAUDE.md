# mach.notch — Project Instructions

Monorepo context: read [`AGENTS.md`](../../AGENTS.md) and [`repo.yaml`](../../repo.yaml) for suite-wide facts, build entrypoints, and policies. This file is **app-local** (structure, DDD, plugins, standards).

## Overview

macOS SwiftUI app that replaces the MacBook notch with an interactive widget system. Plugin-first architecture — every feature (music, battery, calendar, weather, shelf, webcam, notifications, clipboard, pomodoro, teleprompter, habits) is a plugin. Part of the [mach-mono](https://github.com/larsboes/mach-mono) suite. See `repo.yaml` for system requirements.

## Build & Test

- **Build:** `bazelisk build //Apps/machNotch:machNotch` from repo root
- **Test:** `bazelisk test //Apps/machNotch:machNotchTests //Packages/MachBriefKit:MachBriefKitTests` from repo root
- Always build after changes. Don't commit without a green build

## Directory Structure

```
machNotch/
├── Core/                    # Application layer / coordinators / app bootstrapping
├── AppObjectGraph.swift     # DI root — constructs all services and coordinators
├── ContentView.swift        # Main SwiftUI content view with layout logic
└── machNotchApp.swift       # App entry point

Packages/
├── NotchCore/               # Pure domain models, state machine, and basic settings definitions
├── NotchUI/                 # Reusable components, settings views, visual effects, and design system
├── NotchServices/           # Infrastructure services (API, system status, battery, notifications, sharing, etc.)
├── NotchPlugins/            # Bounded contexts for built-in plugins (Music, Calendar, Weather, HabitTracker, Pomodoro, etc.)
├── NotchSettingsMacro/      # Helper macros for settings generation
├── MachBriefKit/            # Core library for the mach.brief widget system
├── MachSoundKit/            # Audio synthesis engine (Rhodes, step sequencer, beds)
├── MachIntelligenceKit/     # AI / local ML processing helpers
└── MacroVisionKit/          # Private system display/window capture API wrapper
```

## DDD Layer Boundaries

| Layer | Where | Imports | Forbidden |
|-------|-------|---------|-----------|
| **Domain** | `Packages/NotchCore/` | Foundation, Observation, Combine, Defaults | SwiftUI, AppKit |
| **Application** | `machNotch/Core/` coordinators + `Packages/NotchPlugins/Core/` | Domain + SwiftUI/AppKit | Concrete infra types |
| **Infrastructure** | `Packages/NotchServices/` | Anything | — |
| **Presentation** | `Packages/NotchUI/` + Views in `NotchPlugins/` | Application + SwiftUI/AppKit | Direct Defaults, concrete services |

## Plugin System

- Each plugin conforms to `NotchPlugin` (in `NotchPlugins`), receives deps via `PluginContext.activate()`
- Plugins communicate via `PluginEventBus` only — never import each other
- Plugin views live inside `Packages/NotchPlugins/Sources/NotchPlugins/BuiltIn/*/Views/`
- HUD requests: publish `SneakPeekRequestedEvent` — never call coordinator directly
- New features → new `NotchPlugin`.

## Code Standards

- **Max 300 lines** per file (hard limit). Target 200.
- **`@Observable` + `@MainActor`** for all state. No `ObservableObject`/`@Published`.
- **Protocol-based services** via `ServiceContainer`. No `.shared` singletons in views/services.
- **No direct `Defaults[.]`** outside `DefaultsNotchSettings.swift`. Use `@Environment(\.bindableSettings)`.
- **No service construction in views.** Views receive dependencies; never create them.
- Allowed `.shared` exceptions: `NSWorkspace`, `NSApplication`, `URLSession`, `URLCache`, `XPCHelperClient`, `FullScreenMonitor`, `QLThumbnailGenerator`, `QLPreviewPanel`, `NSScreenUUIDCache`, `SkyLightOperator`, `DefaultsNotchSettings` (injection root only), `ScreenDisplayRegistry` (system-level screen cache), `BrowserExtensionServer`, `DictionaryEntryCache`.
- **File splits & visibility:** when splitting large files into extensions across separate files, change `private` properties to `internal` (omit `private` keyword) so they can be accessed from the extension files.


## Key Responsibilities

| Component | Owns | Does NOT own |
|-----------|------|-------------|
| **NotchViewModel** | Per-screen state, notch open/close, sizing delegation | Shared UI state |
| **NotchViewCoordinator** | Shared cross-screen state (sneakPeek, expandingView, helloAnimation) | Per-screen state |
| **WindowCoordinator** | Multi-display window lifecycle and app activation (use `updateNotchSize()` on app switch) | Direct `notchSize` overwrites |
| **NotchSizeCalculator** | ALL closed-notch sizing via `ClosedNotchInput` struct | Service dependencies |
| **NotchStateMachine** | Display state determination (pure domain). Must prioritize layouts (e.g., Battery expanding views) over lower-priority plugins. | UI, services |
| **NotchContentRouter** | Which content to show for each display state | State determination |

## Sizing Subsystem

`NotchSizeCalculator` (in `NotchCore`) is the single source of truth for closed notch geometry. It receives a `ClosedNotchInput` value type (no service deps) and computes `effectiveClosedNotchSize`, `effectiveClosedNotchHeight`, `chinHeight`. NotchViewModel constructs the input and delegates.
**Note:** When calculating closed sizes, rely on target properties without strictly requiring `phase == .closed`. Restricting size calculations to the terminal closed phase causes sudden width bounces at the end of animations.

## Files to Not Touch

- `Packages/NotchPlugins/Sources/NotchPlugins/Core/NotchPlugin.swift` — stable protocol
- `Packages/NotchPlugins/Sources/NotchPlugins/Core/PluginEventBus.swift` — stable; add new event types as new structs
- `Packages/NotchCore/Sources/NotchCore/Core/NotchStateMachine.swift` — pure domain; only modify if state logic changes
- `Packages/MacroVisionKit/` — MIT private API wrapper (do not modify)
- `mediaremote-adapter/` — pre-built framework, read-only
