# boring.notch — Project Instructions

## Overview
macOS SwiftUI app that replaces the MacBook notch with an interactive widget system. Plugin-first architecture — every feature (music, battery, calendar, weather, shelf, webcam, notifications, clipboard, pomodoro, teleprompter, habits) is a plugin.

## Build & Test
- **Build:** `xcodebuild -scheme boringNotch -destination 'platform=macOS' build 2>&1 | tail -50`
- **Test:** `xcodebuild -scheme boringNotch -destination 'platform=macOS' test 2>&1 | tail -50`
- Always build after changes. Don't commit without a green build.

## Directory Structure

```
boringNotch/
├── Core/                    # Domain + Application layer
│   ├── Domain files         # NotchStateMachine, NotchPhase, SneakPeekTypes,
│   │                        # NotchSettingsSubProtocols, MockNotchSettings
│   │                        # → Must compile WITHOUT SwiftUI/AppKit
│   ├── Controllers          # NotchHoverController, NotchSizeCalculator,
│   │                        # NotchCameraController, NotchObserverManager
│   ├── Coordinators         # WindowCoordinator, NotchContentRouter,
│   │                        # SneakPeekService, KeyboardShortcutCoordinator
│   └── Settings             # DefaultsNotchSettings (+extensions), NotchSettings,
│                            # NotchViewModelSettings, Constants, DefaultsKeys, SettingsTypes
├── ViewModel/               # BoringViewModel + extensions (Camera, Hover, Observers, OpenClose)
├── models/                  # Pure data models only (CalendarModel, EventModel, PlaybackState, etc.)
├── Plugins/
│   ├── Core/                # PluginManager, NotchPlugin, PluginEventBus, PluginSettings
│   ├── Services/            # ALL service protocols + implementations (61 files)
│   │                        # ServiceContainer (DI), protocols, managers, services
│   └── BuiltIn/             # Each plugin = bounded context
│       ├── MusicPlugin/     # Plugin + Views/
│       ├── ShelfPlugin/     # Plugin + Models/ + Services/ + ViewModels/ + Views/
│       ├── CalendarPlugin/  # Plugin + Views/
│       ├── WeatherPlugin/   # Plugin + Views/
│       ├── BatteryPlugin/   # Plugin
│       └── ...              # Webcam, Notifications, Pomodoro, Teleprompter, etc.
├── components/              # Shared UI only — not feature-specific
│   ├── Notch/               # Notch chrome (shape, window, header)
│   ├── Settings/            # Settings views
│   ├── Onboarding/          # First-run flow
│   ├── Effects/             # LiquidGlass, MetalBlurView
│   ├── Live activities/     # HUD views (shared across plugins)
│   └── Tabs/                # Tab navigation
├── BoringViewCoordinator    # Shared cross-screen state (sneakPeek, expandingView)
├── AppObjectGraph           # DI root — constructs all services and coordinators
├── ContentView              # + Appearance, SubViews extensions
├── sizing/                  # matters.swift — pure sizing functions
├── MediaControllers/        # NowPlaying, Spotify, AppleMusic, YouTube, Browser
├── extensions/              # Swift extensions
├── helpers/                 # Utility helpers
└── observers/               # System observers (fullscreen, drag, media keys)
```

## DDD Layer Boundaries

| Layer | Where | Imports | Forbidden |
|-------|-------|---------|-----------|
| **Domain** | `Core/` domain files (5 files) | Foundation, Observation, Combine, Defaults | SwiftUI, AppKit |
| **Application** | `Core/` coordinators + `Plugins/Core/` + `Plugins/BuiltIn/` | Domain + SwiftUI/AppKit | Concrete infra types |
| **Infrastructure** | `Plugins/Services/`, `DefaultsNotchSettings` | Anything | — |
| **Presentation** | `components/`, plugin `Views/`, `ContentView` | Application + SwiftUI/AppKit | Direct Defaults, concrete services |

## Plugin System

- Each plugin conforms to `NotchPlugin`, receives deps via `PluginContext.activate()`
- Plugins communicate via `PluginEventBus` only — never import each other
- Plugin views live inside `Plugins/BuiltIn/*/Views/`
- HUD requests: publish `SneakPeekRequestedEvent` — never call coordinator directly
- New features → new `NotchPlugin`. Never modify `PluginManager` for feature logic.

## Code Standards

- **Max 300 lines** per file (hard limit). Target 200.
- **`@Observable` + `@MainActor`** for all state. No `ObservableObject`/`@Published`.
- **Protocol-based services** via `ServiceContainer`. No `.shared` singletons in views/services.
- **No direct `Defaults[.]`** outside `DefaultsNotchSettings.swift`. Use `@Environment(\.bindableSettings)`.
- **No service construction in views.** Views receive dependencies; never create them.
- Allowed `.shared` exceptions: `NSWorkspace`, `NSApplication`, `URLSession`, `URLCache`, `XPCHelperClient`, `FullScreenMonitor`, `QLThumbnailGenerator`, `QLPreviewPanel`, `NSScreenUUIDCache`, `SkyLightOperator`, `DefaultsNotchSettings` (injection root only).

## Key Responsibilities

| Component | Owns | Does NOT own |
|-----------|------|-------------|
| **BoringViewModel** | Per-screen state, notch open/close, sizing delegation | Shared UI state |
| **BoringViewCoordinator** | Shared cross-screen state (sneakPeek, expandingView, helloAnimation) | Per-screen state |
| **NotchSizeCalculator** | ALL closed-notch sizing via `ClosedNotchInput` struct | Service dependencies |
| **NotchStateMachine** | Display state determination (pure domain) | UI, services |
| **NotchContentRouter** | Which content to show for each display state | State determination |

## Sizing Subsystem

`NotchSizeCalculator` is the single source of truth for closed notch geometry. It receives a `ClosedNotchInput` value type (no service deps) and computes `effectiveClosedNotchSize`, `effectiveClosedNotchHeight`, `chinHeight`. BoringViewModel constructs the input and delegates.

## Files to Not Touch
- `Plugins/Core/NotchPlugin.swift` — stable protocol
- `Plugins/Core/PluginEventBus.swift` — stable; add new event types as new structs
- `Core/NotchStateMachine.swift` — pure domain; only modify if state logic changes
- `private/CGSSpace.swift` — private API wrapper
- `mediaremote-adapter/` — pre-built framework, read-only
