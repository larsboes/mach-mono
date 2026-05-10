> **Skills are the operative layer.** Concise, actionable agent rules live in `.claude/skills/` (auto-synced to `.gemini/skills/` and `.cursor/skills/`). This file is the full human-readable reference — prose, diagrams, and code examples that skills distil from. When rules conflict, the skills take precedence.
>
> Run `task skills:sync` after editing any skill. Run `task skills:check` to verify sync.

# machNotch Plugin Architecture

> **Adapter note:** Canonical architecture docs live in `docs/architecture/overview.md`, and canonical repo facts live in `repo.yaml`. Keep this file as an agent-focused quick reference, not an independent source of truth.
>
> A plugin-first architecture where every feature—including built-ins—is a plugin.
>
> Last updated: 2026-01-01

---

## Table of Contents

1. [Design Principles](#design-principles)
2. [Architecture Overview](#architecture-overview)
3. [Protocol Hierarchy](#protocol-hierarchy)
4. [Plugin Lifecycle](#plugin-lifecycle)
5. [Dependency Injection](#dependency-injection)
6. [View System](#view-system)
7. [Settings & Persistence](#settings--persistence)
8. [Inter-Plugin Communication](#inter-plugin-communication)
9. [Migration Strategy](#migration-strategy)
10. [File Structure](#file-structure)

---

## Design Principles

### 1. Plugin-First
Every feature is a plugin. Built-in features (Music, Calendar, Shelf) use the same APIs as future third-party plugins. This ensures:
- **Dogfooding:** We use what we ship
- **Consistency:** One pattern for everything
- **Extensibility:** Third-parties get first-class APIs

### 2. Protocol-Oriented
Depend on abstractions, not concretions. Every plugin and service is defined by a protocol, enabling:
- **Testability:** Mock any component
- **Flexibility:** Swap implementations at runtime
- **Decoupling:** Components don't know about each other's internals

### 3. Compile-Time First, Runtime-Ready
Start with compile-time plugin registration (built-in plugins). The architecture supports future runtime loading without protocol changes.

### 4. Local-First Data
All plugin data stays on device. Export in standard formats. Sync is opt-in and user-controlled.

---

## Architecture Overview

### Layer Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              SwiftUI Views                                   │
│  ContentView, NotchHomeView, SettingsView                                   │
│  - No direct singleton access                                               │
│  - Receive PluginManager via @Environment                                   │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │ renders
┌─────────────────────────────────▼───────────────────────────────────────────┐
│                            PluginManager                                     │
│  - Owns all active plugins                                                  │
│  - Routes view requests to appropriate plugin                               │
│  - Manages plugin lifecycle (activate/deactivate)                           │
│  - Handles inter-plugin messaging                                           │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │ manages
┌─────────────────────────────────▼───────────────────────────────────────────┐
│                         NotchPlugin Instances                                │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐  ┌──────────────┐ │
│  │  MusicPlugin  │  │ CalendarPlugin│  │  ShelfPlugin  │  │ WeatherPlugin│ │
│  │  :Playable    │  │  :Exportable  │  │  :Exportable  │  │              │ │
│  │  :Exportable  │  │               │  │  :DataStoring │  │              │ │
│  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘  └──────┬───────┘ │
└──────────┼──────────────────┼──────────────────┼─────────────────┼──────────┘
           │ uses             │ uses             │ uses            │ uses
┌──────────▼──────────────────▼──────────────────▼─────────────────▼──────────┐
│                          Service Protocols                                   │
│  MusicService, CalendarService, ShelfService, WeatherService                │
│  - Wrap system APIs (MediaPlayer, EventKit, etc.)                           │
│  - Stateless or minimal state                                               │
│  - Injected into plugins via PluginContext                                  │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │ accesses
┌─────────────────────────────────▼───────────────────────────────────────────┐
│                            Infrastructure                                    │
│  - System APIs (MediaPlayer, EventKit, CoreAudio, ScreenCaptureKit)         │
│  - Persistence (PluginSettings wrapping Defaults)                           │
│  - Networking (for Weather, future sync)                                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Component Relationships

```
                              ┌─────────────────┐
                              │  machNotchApp │
                              └────────┬────────┘
                                       │ creates
                              ┌────────▼────────┐
                              │ PluginManager   │
                              │ (single source) │
                              └────────┬────────┘
                                       │
           ┌───────────────┬───────────┼───────────┬───────────────┐
           │               │           │           │               │
    ┌──────▼──────┐ ┌──────▼──────┐ ┌──▼──┐ ┌──────▼──────┐ ┌──────▼──────┐
    │ MusicPlugin │ │CalendarPlugin│ │ ... │ │ ShelfPlugin │ │ 3rd Party   │
    └──────┬──────┘ └──────┬──────┘ └─────┘ └──────┬──────┘ └──────┬──────┘
           │               │                       │               │
    ┌──────▼──────┐ ┌──────▼──────┐         ┌──────▼──────┐        │
    │MusicService │ │CalendarSvc  │         │ ShelfService│        │
    │(wraps       │ │(wraps       │         │             │        │
    │ MediaPlayer)│ │ EventKit)   │         │             │        │
    └─────────────┘ └─────────────┘         └─────────────┘        │
                                                                    │
                                                    Uses public plugin APIs
```

---

## Protocol Hierarchy

### Core Plugin Protocol

```swift
/// The fundamental protocol every plugin must implement.
/// Defines identity, lifecycle, and UI slots.
@MainActor
protocol NotchPlugin: Identifiable, Observable {
    /// Unique reverse-DNS identifier (e.g., "com.machnotch.music")
    var id: String { get }

    /// Display metadata for settings UI
    var metadata: PluginMetadata { get }

    /// Whether user has enabled this plugin
    var isEnabled: Bool { get set }

    /// Current loading/error state
    var state: PluginState { get }

    // MARK: - Lifecycle

    /// Called when plugin is enabled. Set up observers, load data.
    func activate(context: PluginContext) async throws

    /// Called when plugin is disabled. Clean up resources.
    func deactivate() async

    // MARK: - UI Slots

    /// Content shown in the closed notch (compact view)
    /// Return nil if this plugin doesn't show in closed state
    @ViewBuilder func closedNotchContent() -> AnyView?

    /// Content shown when notch is expanded (full panel)
    /// Return nil if this plugin doesn't have an expanded view
    @ViewBuilder func expandedPanelContent() -> AnyView?

    /// Settings UI for this plugin
    @ViewBuilder func settingsContent() -> AnyView?
}

struct PluginMetadata: Sendable {
    let name: String
    let description: String
    let icon: String  // SF Symbol name
    let version: String
    let author: String
    let category: PluginCategory
}

enum PluginCategory: String, CaseIterable, Sendable {
    case media
    case productivity
    case utilities
    case system
    case social
}

enum PluginState: Sendable {
    case inactive
    case activating
    case active
    case error(PluginError)
}
```

### Capability Protocols (Mix-ins)

Plugins adopt these to gain additional functionality:

```swift
/// Plugin can control media playback
protocol PlayablePlugin: NotchPlugin {
    var isPlaying: Bool { get }
    var nowPlaying: NowPlayingInfo? { get }
    var playbackProgress: Double { get }  // 0.0 - 1.0

    func play() async
    func pause() async
    func togglePlayPause() async
    func next() async
    func previous() async
    func seek(to progress: Double) async
}

/// Plugin can export its data
protocol ExportablePlugin: NotchPlugin {
    var supportedExportFormats: [ExportFormat] { get }
    func exportData(format: ExportFormat) async throws -> Data
}

/// Plugin stores persistent data
protocol DataStoringPlugin: NotchPlugin {
    associatedtype DataModel: Codable & Sendable
    var data: DataModel { get }
    func save() async throws
    func load() async throws
}

/// Plugin can receive dropped items
protocol DropReceivingPlugin: NotchPlugin {
    var acceptedDropTypes: [UTType] { get }
    func handleDrop(_ providers: [NSItemProvider]) async -> Bool
}

/// Plugin can send notifications
protocol NotifyingPlugin: NotchPlugin {
    func pendingNotifications() -> [PluginNotification]
}

/// Plugin shows content in closed notch based on position
protocol PositionedPlugin: NotchPlugin {
    var closedNotchPosition: ClosedNotchPosition { get }
}

enum ClosedNotchPosition {
    case left
    case center
    case right
    case replacing(SystemElement)

    enum SystemElement {
        case battery
        case time
        case none
    }
}
```

### Service Protocols

Internal services that plugins use (injected via PluginContext):

```swift
/// Music playback service wrapping MediaPlayer/Spotify/etc.
@MainActor
protocol MusicServiceProtocol: Observable {
    var currentTrack: TrackInfo? { get }
    var playbackState: PlaybackState { get }
    var artwork: NSImage? { get }
    var volume: Float { get }
    var shuffleEnabled: Bool { get }
    var repeatMode: RepeatMode { get }

    func setVolume(_ volume: Float) async
    func setShuffleEnabled(_ enabled: Bool) async
    func setRepeatMode(_ mode: RepeatMode) async

    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> { get }
}

/// Calendar service wrapping EventKit
@MainActor
protocol CalendarServiceProtocol: Observable {
    var todayEvents: [CalendarEvent] { get }
    var upcomingEvents: [CalendarEvent] { get }
    var hasAccess: Bool { get }

    func requestAccess() async throws -> Bool
    func refreshEvents() async throws
    func events(for date: Date) async -> [CalendarEvent]
}

/// Shelf storage service
@MainActor
protocol ShelfServiceProtocol: Observable {
    var items: [ShelfItem] { get }
    var selectedItems: Set<ShelfItem.ID> { get set }

    func addItem(_ item: ShelfItem) async throws
    func removeItem(_ id: ShelfItem.ID) async throws
    func clearAll() async
}

/// Weather data service
@MainActor
protocol WeatherServiceProtocol: Observable {
    var currentWeather: WeatherData? { get }
    var forecast: [WeatherData] { get }
    var lastUpdated: Date? { get }

    func refresh() async throws
    func setLocation(_ location: WeatherLocation) async
}

/// System metrics service
@MainActor
protocol SystemMetricsServiceProtocol: Observable {
    var cpuUsage: Double { get }
    var memoryUsage: Double { get }
    var networkIn: Int64 { get }
    var networkOut: Int64 { get }

    var metricsPublisher: AnyPublisher<SystemMetrics, Never> { get }
}
```

---

## Plugin Lifecycle

### State Machine

```
                    ┌──────────────┐
                    │   Inactive   │◄─────────────────────────┐
                    └──────┬───────┘                          │
                           │ enable()                         │
                    ┌──────▼───────┐                          │
                    │  Activating  │                          │
                    └──────┬───────┘                          │
                           │                                  │
              ┌────────────┴────────────┐                     │
              │                         │                     │
       ┌──────▼───────┐          ┌──────▼───────┐            │
       │    Active    │          │    Error     │            │
       └──────┬───────┘          └──────┬───────┘            │
              │                         │                     │
              │ disable()               │ retry() or disable()│
              └─────────────────────────┴─────────────────────┘
```

### Lifecycle Methods

```swift
extension PluginManager {
    func enablePlugin(_ id: String) async throws {
        guard let plugin = plugins[id] else { throw PluginError.notFound(id) }
        guard plugin.state == .inactive else { return }

        plugin.state = .activating

        do {
            // Create context with services this plugin needs
            let context = PluginContext(
                settings: PluginSettings(pluginId: id),
                services: serviceContainer,
                eventBus: eventBus
            )

            try await plugin.activate(context: context)
            plugin.state = .active
            plugin.isEnabled = true

            eventBus.emit(.pluginActivated(id))
        } catch {
            plugin.state = .error(PluginError.activationFailed(error))
            throw error
        }
    }

    func disablePlugin(_ id: String) async {
        guard let plugin = plugins[id] else { return }

        await plugin.deactivate()
        plugin.state = .inactive
        plugin.isEnabled = false

        eventBus.emit(.pluginDeactivated(id))
    }
}
```

---

## Dependency Injection

### PluginContext

Each plugin receives a context with everything it needs:

```swift
/// Injected into plugins during activation
@MainActor
struct PluginContext {
    /// Plugin-specific settings (namespaced in Defaults)
    let settings: PluginSettings

    /// Access to shared services
    let services: ServiceContainer

    /// For inter-plugin communication
    let eventBus: PluginEventBus

    /// App-wide state
    let appState: AppStateProviding
}

/// Container for all injectable services
@MainActor
final class ServiceContainer {
    // Core services (always available)
    let music: any MusicServiceProtocol
    let calendar: any CalendarServiceProtocol
    let shelf: any ShelfServiceProtocol
    let weather: any WeatherServiceProtocol
    let systemMetrics: any SystemMetricsServiceProtocol

    // System services
    let notifications: NotificationServiceProtocol
    let permissions: PermissionServiceProtocol

    init(
        music: any MusicServiceProtocol = MusicService(),
        calendar: any CalendarServiceProtocol = CalendarService(),
        // ... etc
    ) {
        self.music = music
        self.calendar = calendar
        // ...
    }
}
```

### Service Registration

```swift
// At app launch
@main
struct machNotchApp: App {
    @State private var pluginManager: PluginManager

    init() {
        // Create service container (real implementations)
        let services = ServiceContainer(
            music: MusicService(),
            calendar: CalendarService(),
            shelf: ShelfService(),
            weather: WeatherService()
        )

        // Create plugin manager with built-in plugins
        _pluginManager = State(initialValue: PluginManager(
            services: services,
            builtInPlugins: [
                MusicPlugin(),
                CalendarPlugin(),
                ShelfPlugin(),
                WeatherPlugin(),
                BatteryPlugin(),
                WebcamPlugin()
            ]
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(pluginManager)
        }
    }
}
```

### Testing with Mocks

```swift
// In tests
func testMusicPluginShowsNowPlaying() async {
    let mockMusic = MockMusicService()
    mockMusic.currentTrack = TrackInfo(title: "Test Song", artist: "Test Artist")
    mockMusic.playbackState = .playing

    let services = ServiceContainer(music: mockMusic)
    let plugin = MusicPlugin()

    try await plugin.activate(context: PluginContext(
        settings: PluginSettings(pluginId: "test"),
        services: services,
        eventBus: PluginEventBus()
    ))

    XCTAssertNotNil(plugin.nowPlaying)
    XCTAssertEqual(plugin.nowPlaying?.title, "Test Song")
}
```

---

## View System

### View Slots

Plugins provide views for three slots:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CLOSED NOTCH                                       │
│  ┌─────────┐ ┌─────────────────────────────────┐ ┌─────────┐ ┌─────────────┐│
│  │  Left   │ │            Center               │ │  Right  │ │  Far Right  ││
│  │ Plugin  │ │ Plugin (e.g., now playing)      │ │ Plugin  │ │  (Battery)  ││
│  └─────────┘ └─────────────────────────────────┘ └─────────┘ └─────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                          EXPANDED PANEL                                      │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  Tab Bar: [Music] [Calendar] [Shelf] [Weather] [...]                    ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                                                                          ││
│  │                    Active Plugin's expandedPanelContent()               ││
│  │                                                                          ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                           SETTINGS                                           │
│  ┌──────────────────┐  ┌────────────────────────────────────────────────────┐│
│  │ Sidebar          │  │                                                    ││
│  │ ─────────────────│  │  Selected Plugin's settingsContent()              ││
│  │ General          │  │                                                    ││
│  │ Appearance       │  │                                                    ││
│  │ ─────────────────│  │                                                    ││
│  │ Music      [✓]   │  │                                                    ││
│  │ Calendar   [✓]   │  │                                                    ││
│  │ Shelf      [✓]   │  │                                                    ││
│  │ Weather    [ ]   │  │                                                    ││
│  └──────────────────┘  └────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

### View Composition

```swift
// In ContentView or NotchContentRouter
struct ExpandedNotchContent: View {
    @Environment(PluginManager.self) var pluginManager
    @State private var selectedTab: String?

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar from active plugins
            PluginTabBar(
                plugins: pluginManager.activePlugins,
                selected: $selectedTab
            )

            // Active plugin's content
            if let plugin = pluginManager.plugin(id: selectedTab) {
                plugin.expandedPanelContent()
            }
        }
    }
}

struct ClosedNotchContent: View {
    @Environment(PluginManager.self) var pluginManager

    var body: some View {
        HStack {
            // Left slot
            ForEach(pluginManager.plugins(at: .left)) { plugin in
                plugin.closedNotchContent()
            }

            Spacer()

            // Center slot (usually music now playing)
            ForEach(pluginManager.plugins(at: .center)) { plugin in
                plugin.closedNotchContent()
            }

            Spacer()

            // Right slot
            ForEach(pluginManager.plugins(at: .right)) { plugin in
                plugin.closedNotchContent()
            }
        }
    }
}
```

---

## Settings & Persistence

### PluginSettings Wrapper

Each plugin gets namespaced settings:

```swift
/// Wraps Defaults with plugin-specific namespace
@MainActor
final class PluginSettings: Observable {
    private let pluginId: String
    private let prefix: String

    init(pluginId: String) {
        self.pluginId = pluginId
        self.prefix = "plugin.\(pluginId)."
    }

    /// Get a setting value
    func get<T: Defaults.Serializable>(_ key: String, default defaultValue: T) -> T {
        let fullKey = Defaults.Key<T>("\(prefix)\(key)", default: defaultValue)
        return Defaults[fullKey]
    }

    /// Set a setting value
    func set<T: Defaults.Serializable>(_ key: String, value: T) {
        let fullKey = Defaults.Key<T>("\(prefix)\(key)", default: value)
        Defaults[fullKey] = value
    }

    /// Observe changes to a setting
    func observe<T: Defaults.Serializable>(
        _ key: String,
        default defaultValue: T
    ) -> AnyPublisher<T, Never> {
        let fullKey = Defaults.Key<T>("\(prefix)\(key)", default: defaultValue)
        return Defaults.publisher(fullKey).map(\.newValue).eraseToAnyPublisher()
    }

    /// Plugin enabled state (special case, always available)
    var isEnabled: Bool {
        get { get("enabled", default: true) }
        set { set("enabled", value: newValue) }
    }
}

// Usage in plugin
class MusicPlugin: NotchPlugin {
    private var settings: PluginSettings!

    func activate(context: PluginContext) async throws {
        self.settings = context.settings

        // Access plugin-specific settings
        let showLyrics = settings.get("showLyrics", default: true)
        let artworkStyle = settings.get("artworkStyle", default: "rounded")
    }
}
```

### Migration from Current Settings

```swift
/// One-time migration from old Defaults keys to plugin-namespaced keys
struct SettingsMigration {
    static func migrateIfNeeded() {
        guard !Defaults[.hasMigratedToPluginSettings] else { return }

        // Music plugin settings
        migrateKey(from: .showMusicLiveActivity, to: "plugin.com.machnotch.music.showLiveActivity")
        migrateKey(from: .enableSneakPeek, to: "plugin.com.machnotch.music.enableSneakPeek")

        // Calendar plugin settings
        migrateKey(from: .showCalendar, to: "plugin.com.machnotch.calendar.enabled")

        // Shelf plugin settings
        migrateKey(from: .shelfEnabled, to: "plugin.com.machnotch.shelf.enabled")

        Defaults[.hasMigratedToPluginSettings] = true
    }
}
```

---

## Inter-Plugin Communication

### Event Bus

For loose coupling between plugins:

```swift
/// Central event bus for plugin communication
@MainActor
final class PluginEventBus: Observable {
    private var subscribers: [PluginEventType: [(any PluginEventHandler)]] = [:]
    private let eventSubject = PassthroughSubject<PluginEvent, Never>()

    var events: AnyPublisher<PluginEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    func emit(_ event: PluginEvent) {
        eventSubject.send(event)
    }

    func subscribe<T: PluginEvent>(
        to eventType: T.Type,
        handler: @escaping (T) async -> Void
    ) -> AnyCancellable {
        events
            .compactMap { $0 as? T }
            .sink { event in
                Task { await handler(event) }
            }
    }
}

/// Base event protocol
protocol PluginEvent: Sendable {
    var sourcePluginId: String { get }
    var timestamp: Date { get }
}

/// Concrete events
struct MusicPlaybackChangedEvent: PluginEvent {
    let sourcePluginId = "com.machnotch.music"
    let timestamp = Date()
    let isPlaying: Bool
    let track: TrackInfo?
}

struct CalendarEventStartingSoonEvent: PluginEvent {
    let sourcePluginId = "com.machnotch.calendar"
    let timestamp = Date()
    let event: CalendarEvent
    let startsIn: TimeInterval
}

struct ShelfItemAddedEvent: PluginEvent {
    let sourcePluginId = "com.machnotch.shelf"
    let timestamp = Date()
    let item: ShelfItem
}
```

### Direct Service Access

For tight coupling (e.g., Meeting plugin needs Calendar data):

```swift
class MeetingPlugin: NotchPlugin {
    private var calendarService: CalendarServiceProtocol!

    func activate(context: PluginContext) async throws {
        // Direct access to calendar service
        self.calendarService = context.services.calendar

        // Subscribe to calendar events
        context.eventBus.subscribe(to: CalendarEventStartingSoonEvent.self) { [weak self] event in
            await self?.handleUpcomingMeeting(event.event)
        }
    }

    func upcomingMeetings() async -> [CalendarEvent] {
        // Direct query
        return await calendarService.upcomingEvents.filter { $0.isMeeting }
    }
}
```

---

## Migration Strategy

### Phase 1: Foundation (Current Sprint)

1. Create `Plugins/` directory structure
2. Define core protocols (`NotchPlugin`, capabilities, services)
3. Create `PluginManager` and `PluginContext`
4. Keep existing code working (no breaking changes)

### Phase 2: First Plugin Migration

1. Create `MusicPlugin` wrapping existing `MusicManager`
2. `MusicManager` becomes `MusicService: MusicServiceProtocol`
3. Update `NotchContentRouter` to query `PluginManager`
4. Verify existing functionality unchanged

### Phase 3: Remaining Built-ins

| Order | Plugin | Wraps | Complexity |
|-------|--------|-------|------------|
| 1 | MusicPlugin | MusicManager | Medium |
| 2 | BatteryPlugin | BatteryStatusViewModel | Low |
| 3 | CalendarPlugin | CalendarManager | Medium |
| 4 | ShelfPlugin | ShelfStateViewModel + services | High |
| 5 | WeatherPlugin | WeatherManager | Low |
| 6 | WebcamPlugin | WebcamManager | Low |
| 7 | NotificationsPlugin | NotificationCenterManager | Medium |

### Phase 4: Cleanup

1. Remove old singleton `.shared` access from views
2. Delete `DependencyContainer` (replaced by `ServiceContainer`)
3. Migrate remaining `Defaults[.]` to `PluginSettings`
4. Update all views to use `@Environment(PluginManager.self)`

### Phase 5: New Plugins

With architecture in place, add new plugins:
- HabitTrackerPlugin
- PomodoroPlugin
- ClipboardHistoryPlugin
- SystemStatsPlugin

---

## File Structure

```
machNotch/
├── Plugins/
│   ├── Core/
│   │   ├── NotchPlugin.swift           # Core plugin protocol
│   │   ├── PluginCapabilities.swift    # Capability protocols (Playable, Exportable, etc.)
│   │   ├── PluginManager.swift         # Plugin registry and lifecycle
│   │   ├── PluginContext.swift         # Dependency injection context
│   │   ├── PluginSettings.swift        # Settings wrapper
│   │   ├── PluginEventBus.swift        # Inter-plugin communication
│   │   └── PluginTypes.swift           # Shared types (Metadata, State, etc.)
│   │
│   ├── Services/
│   │   ├── ServiceContainer.swift      # All injectable services
│   │   ├── MusicService.swift          # MusicServiceProtocol impl
│   │   ├── CalendarService.swift       # CalendarServiceProtocol impl
│   │   ├── ShelfService.swift          # ShelfServiceProtocol impl
│   │   └── WeatherService.swift        # WeatherServiceProtocol impl
│   │
│   └── BuiltIn/
│       ├── MusicPlugin/
│       │   ├── MusicPlugin.swift       # Plugin implementation
│       │   └── Views/
│       │       ├── MusicClosedView.swift
│       │       ├── MusicExpandedView.swift
│       │       └── MusicSettingsView.swift
│       │
│       ├── CalendarPlugin/
│       │   ├── CalendarPlugin.swift
│       │   └── Views/...
│       │
│       ├── ShelfPlugin/
│       │   ├── ShelfPlugin.swift
│       │   └── Views/...
│       │
│       └── ... (Weather, Battery, Webcam, etc.)
│
├── Core/
│   ├── NotchStateMachine.swift         # Unchanged
│   ├── WindowCoordinator.swift         # Unchanged
│   └── NotchContentRouter.swift        # Updated to use PluginManager
│
└── ... (rest of existing structure)
```

---

## Appendix: Type Definitions

```swift
// MARK: - Music Types

struct TrackInfo: Codable, Sendable {
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval
    let artworkURL: URL?
}

struct NowPlayingInfo: Sendable {
    let track: TrackInfo
    let artwork: NSImage?
    let progress: Double
    let isPlaying: Bool
}

enum PlaybackState: String, Codable, Sendable {
    case playing, paused, stopped
}

enum RepeatMode: String, Codable, Sendable {
    case off, one, all
}

// MARK: - Calendar Types

struct CalendarEvent: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let calendarColor: String

    var isMeeting: Bool {
        // Heuristic: has video link or attendees
        title.lowercased().contains("meeting") ||
        title.lowercased().contains("call")
    }
}

// MARK: - Export Types

enum ExportFormat: String, CaseIterable, Sendable {
    case json
    case csv
    case xml
    case ical
    case markdown
    case html
}

// MARK: - Error Types

enum PluginError: Error, LocalizedError {
    case notFound(String)
    case activationFailed(Error)
    case permissionDenied(String)
    case invalidState(PluginState)
    case exportFailed(ExportFormat, Error)

    var errorDescription: String? {
        switch self {
        case .notFound(let id): return "Plugin not found: \(id)"
        case .activationFailed(let error): return "Activation failed: \(error.localizedDescription)"
        case .permissionDenied(let perm): return "Permission denied: \(perm)"
        case .invalidState(let state): return "Invalid state: \(state)"
        case .exportFailed(let format, let error): return "Export to \(format) failed: \(error.localizedDescription)"
        }
    }
}
```

---

*This architecture enables machNotch to evolve from a monolithic app to a plugin platform while maintaining stability during the transition.*
# Plugin Architecture Conventions

> **Adapter note:** Canonical repo facts live in `repo.yaml`; product and architecture details live in `docs/prds/machNotch.md` and `docs/architecture/overview.md`. Keep this file as an agent-focused checklist.
>
> **Purpose:** Define the coding patterns and conventions for the plugin architecture to ensure consistency and avoid common pitfalls.

---

## 1. Settings Pattern (Dual Environment Keys)

**Problem:** We need protocol-based dependency injection for testing, but SwiftUI views often need concrete classes for `@Bindable` two-way bindings.

**Solution:** Use two separate environment keys.

### Implementation

```swift
// 1. Read-Only Key (Protocol)
// Use this for most views that just need to read settings.
// Testable with MockNotchSettings.
extension EnvironmentValues {
    var settings: any NotchSettings { get set }
}

// 2. Bindable Key (Concrete Class)
// Use this ONLY for settings views that need $settings bindings.
extension EnvironmentValues {
    var bindableSettings: DefaultsNotchSettings { get set }
}
```

### Usage Guidelines

**✅ DO:**
```swift
// Reading settings
struct UserProfileView: View {
    @Environment(\.settings) var settings // Protocol type
    
    var body: some View {
        if settings.showAvatar { ... }
    }
}

// Binding settings (Settings Views only)
struct GeneralSettingsView: View {
    @Environment(\.bindableSettings) var settings // Concrete type
    
    var body: some View {
        Toggle("Show Avatar", isOn: $settings.showAvatar)
    }
}
```

**❌ DON'T:**
- Don't use `@Environment(\.bindableSettings)` in standard views.
- Don't cast `settings` to `DefaultsNotchSettings`.

---

## 2. Service Protocols

**Principle:** Service protocols should mirror the *actual* manager APIs, not idealized interfaces.

**Rationale:** The goal is to wrap existing managers to enable DI, not to redesign the entire system at once.

**Guidelines:**
- **Match Properties:** If `MusicManager` has `playbackState`, `MusicServiceProtocol` must have `playbackState`.
- **Match Types:** Use the exact types defined in the codebase (e.g., `PlaybackState` struct, not a new enum).
- **Minimal Changes:** Don't add methods or properties that don't exist in the underlying manager yet.

---

## 3. AppStateProviding

**Principle:** Start minimal and expand incrementally.

**Rationale:** Avoiding "over-specifying" the protocol prevents build errors and implementation burden for properties that aren't actually used yet.

**Current MVP:**
```swift
protocol AppStateProviding: AnyObject {
    var isScreenLocked: Bool { get }
}
```

**Evolution:** Add properties (e.g., `isNotchExpanded`, `currentScreen`) only when a plugin specifically requires them.

---

## 4. MainActor Isolation

**Rule:** All UI-related protocols and classes must be `@MainActor`.

**Reasoning:**
- SwiftUI views are `@MainActor`.
- Environment objects are accessed from the main thread.
- `DefaultsNotchSettings` and Managers are stateful and interact with UI.

**Common Pitfall:**
- Environment key default values cannot synchronously instantiate `@MainActor` classes if the key itself isn't isolated.
- **Fix:** Use `nonisolated(unsafe)` for the default value if necessary, or ensure the type is thread-safe.
# Design System: Minimalistic Aesthetic

> **Adapter note:** Durable repo facts belong in `repo.yaml`; product-specific design scope belongs in the relevant PRD under `docs/prds/`. Keep this file as a concise cross-app design checklist.

All applications within this monorepo must adhere to a strict **Minimalistic Aesthetic**. 

## Core Principles
1. **Clarity:** Every element must serve a functional purpose. Remove non-essential UI.
2. **Cohesion:** Consistent use of spacing, typography, and color across all apps.
3. **Tech-Forward:** Design should be clean, modern, and high-performance.
4. **Subtlety:** Use soft shadows, refined gradients, and intentional color accents (neon-blue/purple) to guide attention.

## Iconography
- Icons must be legible at small sizes (16x16).
- Avoid excessive detail; favor abstract, geometric representations.
- Use a consistent, dark, sleek palette with vibrant accents.
# machNotch Feature Ideas

> **Adapter note:** This is an agent brainstorming reference. The authoritative feature roadmap and plugin specs live in `docs/prds/machNotch.md`.
>
> **Design Principle:** Every feature is a plugin. No vendor lock-in. Data is exportable. APIs are local-first.
> 
> Last updated: 2026-05-02
For the authoritative feature roadmap and plugin specs, see `docs/prds/machNotch.md → Phase 16`.

---

## Core Philosophy

### Plugin-First Architecture
Every feature—including built-in ones like Music, Calendar, Shelf—should be implemented as plugins. This ensures:
- **Modularity:** Users enable only what they need
- **Extensibility:** Third-parties can build on the same APIs we use
- **Testability:** Isolated, well-defined boundaries
- **Maintainability:** No god objects, clear ownership

### Open Data Principles
1. **No Vendor Lock-in:** All user data exportable in standard formats (JSON, CSV, iCal, etc.)
2. **Local-First:** Data stays on device unless user explicitly opts for sync
3. **API Exposure:** Local HTTP/Unix socket API for other apps to integrate
4. **Standard Formats:** Use existing standards (CalDAV, WebDAV, ActivityPub) where possible

### Integration Philosophy
```
┌─────────────────────────────────────────────────────────────────┐
│                    machNotch Core                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │ Plugin Host │  │ Data Layer  │  │ Local API   │             │
│  │             │  │ (Exportable)│  │ (REST/gRPC) │             │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘             │
└─────────┼────────────────┼────────────────┼─────────────────────┘
          │                │                │
    ┌─────▼─────┐    ┌─────▼─────┐    ┌─────▼─────┐
    │  Plugins  │    │  Export   │    │  External │
    │ (1st/3rd) │    │  Formats  │    │   Apps    │
    └───────────┘    └───────────┘    └───────────┘
```

---

## 1. Plugin System Architecture

### Plugin Protocol
```swift
protocol NotchPlugin: Identifiable {
    var id: String { get }
    var metadata: PluginMetadata { get }
    
    // Lifecycle
    func activate() async throws
    func deactivate() async
    
    // UI Slots
    func closedNotchView() -> AnyView?
    func openPanelView() -> AnyView?
    func settingsView() -> AnyView?
    func menuBarView() -> AnyView?  // Optional menu bar extra
    
    // Data & Export
    var dataStore: PluginDataStore? { get }
    func exportData(format: ExportFormat) async throws -> Data
    
    // Inter-plugin communication
    func handleMessage(_ message: PluginMessage) async -> PluginResponse?
}

struct PluginMetadata {
    let name: String
    let version: String
    let author: String
    let description: String
    let permissions: [PluginPermission]
    let dataFormats: [ExportFormat]  // What formats this plugin can export
}

enum ExportFormat: String, CaseIterable {
    case json, csv, xml, ical, markdown, html
}
```

### Plugin Slots System
```swift
enum PluginSlot {
    case closedNotch(position: ClosedNotchPosition)
    case openPanel(tab: String)
    case settingsPane
    case menuBarExtra
    case backgroundService  // No UI, just runs
    
    enum ClosedNotchPosition {
        case left, center, right
        case replacing(BuiltInElement)  // Replace battery, time, etc.
    }
}
```

### Plugin Manager
```swift
@MainActor
final class PluginManager: ObservableObject {
    private var loadedPlugins: [String: NotchPlugin] = [:]
    private let pluginDirectory: URL
    private let localAPI: LocalAPIServer
    
    // Discovery
    func discoverPlugins() async -> [PluginMetadata]
    func loadPlugin(id: String) async throws
    func unloadPlugin(id: String) async
    
    // Data Export (unified across all plugins)
    func exportAllData(format: ExportFormat) async throws -> URL
    func exportPluginData(pluginId: String, format: ExportFormat) async throws -> Data
    
    // Inter-plugin messaging
    func send(_ message: PluginMessage, to pluginId: String) async -> PluginResponse?
    func broadcast(_ message: PluginMessage) async
}
```

### Plugin Data Store
```swift
protocol PluginDataStore {
    associatedtype DataModel: Codable
    
    var data: DataModel { get set }
    
    // Persistence
    func save() async throws
    func load() async throws
    
    // Export (plugins implement these)
    func toJSON() -> Data
    func toCSV() -> String
    func toMarkdown() -> String
    
    // Sync (optional)
    var syncProvider: SyncProvider? { get }
}

protocol SyncProvider {
    func push() async throws
    func pull() async throws
    var lastSynced: Date? { get }
}
```

### Plugin Distribution
```
Formats:
├── .machplugin          # Signed bundle (like .app)
├── Swift Package        # Source distribution via SPM
├── npm package          # For JS/WebView plugins
└── GitHub release       # Direct download

Discovery:
├── Built-in catalog     # Curated, reviewed plugins
├── GitHub topics        # #machnotch-plugin
└── Local folder         # ~/Library/Application Support/machNotch/Plugins/
```

---

## 2. Local API Server

### Purpose
Expose machNotch functionality to external apps, scripts, and automations.

### Implementation
```swift
final class LocalAPIServer {
    private let port: UInt16 = 19384  // Or Unix socket
    
    // REST-ish endpoints
    // GET  /api/v1/plugins              - List plugins
    // GET  /api/v1/plugins/{id}/data    - Get plugin data
    // POST /api/v1/plugins/{id}/action  - Trigger action
    // GET  /api/v1/export/{format}      - Export all data
    // WS   /api/v1/events               - Real-time events stream
    
    // Authentication: Local-only by default, optional token for remote
}
```

### Event Stream (WebSocket)
```json
{
    "type": "notch.stateChanged",
    "data": {
        "state": "open",
        "trigger": "hover"
    }
}

{
    "type": "music.playbackChanged",
    "data": {
        "isPlaying": true,
        "track": "Song Name",
        "artist": "Artist"
    }
}

{
    "type": "plugin.dataChanged",
    "pluginId": "habit-tracker",
    "data": { ... }
}
```

### CLI Tool
```bash
# Ship a CLI for power users
$ machnotch status
Notch: closed
Active plugins: music, calendar, shelf, habit-tracker

$ machnotch export --format csv --output ~/Desktop/
Exported 4 plugins to ~/Desktop/machnotch-export-2025-12-30/

$ machnotch plugin install github:user/cool-plugin

$ machnotch api start --port 19384
Local API server running at http://localhost:19384
```

---

## 3. Built-In Plugins (Refactored from Current Features)

### Music Plugin
```swift
struct MusicPlugin: NotchPlugin {
    let id = "com.machnotch.music"
    
    // Data export
    func exportData(format: ExportFormat) async throws -> Data {
        // Export listening history, favorites, etc.
        switch format {
        case .json: return try JSONEncoder().encode(listeningHistory)
        case .csv: return listeningHistory.toCSV()
        }
    }
    
    // API endpoints this plugin adds
    // GET  /api/v1/music/now-playing
    // POST /api/v1/music/play
    // POST /api/v1/music/pause
    // GET  /api/v1/music/history
}
```

### Calendar Plugin
```swift
struct CalendarPlugin: NotchPlugin {
    let id = "com.machnotch.calendar"
    
    // Export: iCal format for portability
    func exportData(format: ExportFormat) async throws -> Data {
        switch format {
        case .ical: return generateICalFeed()
        case .json: return try JSONEncoder().encode(events)
        }
    }
}
```

### Shelf Plugin
```swift
struct ShelfPlugin: NotchPlugin {
    let id = "com.machnotch.shelf"
    
    // Export: File list, metadata
    func exportData(format: ExportFormat) async throws -> Data {
        // Export shelf contents metadata (not the files themselves)
    }
    
    // WebDAV-like API for other apps
    // GET  /api/v1/shelf/items
    // POST /api/v1/shelf/items    (add item)
    // DELETE /api/v1/shelf/items/{id}
}
```

---

## 4. New Feature Plugins

### 4.1 Habit Tracker Plugin

**Philosophy:** Your habit data belongs to you. Export anytime, sync anywhere.

```swift
struct HabitTrackerPlugin: NotchPlugin {
    let id = "com.machnotch.habits"
    
    struct HabitData: Codable {
        var habits: [Habit]
        var completions: [HabitCompletion]
        var streaks: [String: Int]
    }
    
    struct Habit: Codable, Identifiable {
        let id: UUID
        var name: String
        var frequency: Frequency
        var createdAt: Date
        var archivedAt: Date?
    }
    
    struct HabitCompletion: Codable {
        let habitId: UUID
        let date: Date
        let notes: String?
    }
    
    // Export formats
    func exportData(format: ExportFormat) async throws -> Data {
        switch format {
        case .csv:
            return """
            habit_id,habit_name,date,completed,notes
            \(completions.map { "\($0.habitId),\(habit(for: $0).name),\($0.date),true,\($0.notes ?? "")" }.joined(separator: "\n"))
            """.data(using: .utf8)!
        case .json:
            return try JSONEncoder().encode(data)
        case .markdown:
            return generateMarkdownReport()
        }
    }
    
    // Sync options (user chooses, we don't lock in)
    var syncProviders: [SyncProvider] {
        [
            iCloudSyncProvider(),
            FileSyncProvider(path: userChosenPath),  // Obsidian vault, Dropbox, etc.
            CalDAVSyncProvider(),  // Sync as calendar events
        ]
    }
    
    // API
    // GET  /api/v1/habits
    // POST /api/v1/habits/{id}/complete
    // GET  /api/v1/habits/export?format=csv
}
```

**UI:**
- Closed notch: Today's habits as dots (filled = done)
- Open panel: Full habit list with check buttons
- Settings: Reminder times, export options, sync setup

---

### 4.2 Pomodoro/Focus Timer Plugin

```swift
struct PomodoroPlugin: NotchPlugin {
    let id = "com.machnotch.pomodoro"
    
    struct SessionData: Codable {
        var sessions: [PomodoroSession]
        var settings: PomodoroSettings
    }
    
    struct PomodoroSession: Codable {
        let id: UUID
        let startTime: Date
        let duration: TimeInterval
        let type: SessionType  // work, shortBreak, longBreak
        let completed: Bool
        let tag: String?  // "coding", "writing", etc.
    }
    
    // Export for time tracking apps
    func exportData(format: ExportFormat) async throws -> Data {
        switch format {
        case .csv:
            // Compatible with Toggl, Clockify CSV imports
            return """
            Start,End,Duration,Type,Tag
            \(sessions.map { "\($0.startTime),\($0.endTime),\($0.duration),\($0.type),\($0.tag ?? "")" }.joined(separator: "\n"))
            """.data(using: .utf8)!
        case .json:
            return try JSONEncoder().encode(sessions)
        }
    }
    
    // Integration with Focus modes
    func activate() async throws {
        // Optionally enable Focus mode during work sessions
    }
    
    // API
    // POST /api/v1/pomodoro/start
    // POST /api/v1/pomodoro/stop
    // GET  /api/v1/pomodoro/status
    // GET  /api/v1/pomodoro/history
}
```

---

### 4.3 System Stats Plugin

```swift
struct SystemStatsPlugin: NotchPlugin {
    let id = "com.machnotch.stats"
    
    // Real-time metrics
    struct SystemMetrics: Codable {
        let timestamp: Date
        let cpu: CPUMetrics
        let memory: MemoryMetrics
        let network: NetworkMetrics
        let disk: DiskMetrics
    }
    
    // Historical data (for graphs, export)
    var metricsHistory: [SystemMetrics] = []
    
    func exportData(format: ExportFormat) async throws -> Data {
        // Export for analysis in other tools
        switch format {
        case .csv:
            return metricsToCSV()  // Timestamp, CPU%, RAM%, Network In/Out
        case .json:
            return try JSONEncoder().encode(metricsHistory)
        }
    }
    
    // API (for other monitoring tools)
    // GET /api/v1/stats/current
    // GET /api/v1/stats/history?since=2025-01-01
    // WS  /api/v1/stats/stream  (real-time updates)
}
```

---

### 4.4 Quick Notes Plugin

```swift
struct QuickNotesPlugin: NotchPlugin {
    let id = "com.machnotch.notes"
    
    struct Note: Codable, Identifiable {
        let id: UUID
        var content: String
        var createdAt: Date
        var modifiedAt: Date
        var tags: [String]
        var linkedNoteIds: [UUID]  // Bi-directional links
    }
    
    // Export: Standard formats for note apps
    func exportData(format: ExportFormat) async throws -> Data {
        switch format {
        case .markdown:
            // Each note as .md file in a zip
            return try await exportAsMarkdownZip()
        case .json:
            // Obsidian-compatible JSON
            return try JSONEncoder().encode(notes)
        case .html:
            return generateHTMLExport()
        }
    }
    
    // Sync: File-based for Obsidian/iA Writer/etc.
    var syncProviders: [SyncProvider] {
        [
            FileSyncProvider(path: "~/Documents/machNotch Notes"),
            ObsidianVaultProvider(vaultPath: userVaultPath),
            AppleNotesProvider(),  // Via Shortcuts
        ]
    }
    
    // API
    // POST /api/v1/notes          (create note)
    // GET  /api/v1/notes          (list notes)
    // GET  /api/v1/notes/search?q=query
}
```

---

### 4.5 Clipboard History Plugin

```swift
struct ClipboardPlugin: NotchPlugin {
    let id = "com.machnotch.clipboard"
    
    struct ClipboardEntry: Codable, Identifiable {
        let id: UUID
        let content: ClipboardContent
        let timestamp: Date
        let sourceApp: String?
        var pinned: Bool
        var tags: [String]
    }
    
    enum ClipboardContent: Codable {
        case text(String)
        case image(Data)  // PNG data
        case file(URL)
        case richText(Data)  // RTF data
    }
    
    // Export
    func exportData(format: ExportFormat) async throws -> Data {
        switch format {
        case .json:
            return try JSONEncoder().encode(history)
        case .csv:
            // Text entries only
            return textEntriesToCSV()
        }
    }
    
    // Privacy: Auto-clear options
    var settings: ClipboardSettings {
        autoClearAfter: .hours(24),
        excludeApps: ["1Password", "Keychain"],
        excludeTypes: [.password]  // Detect and exclude passwords
    }
    
    // API
    // GET  /api/v1/clipboard/history
    // POST /api/v1/clipboard/paste/{id}
    // DELETE /api/v1/clipboard/clear
}
```

---

### 4.6 Audio Visualizer Plugin

```swift
struct AudioVisualizerPlugin: NotchPlugin {
    let id = "com.machnotch.visualizer"
    
    // Visualizer presets (extendable)
    var presets: [VisualizerPreset] = [
        .bars,
        .waveform,
        .particles,
        .blob,        // Endel-style organic shapes
        .custom(...)  // User-defined Metal shaders
    ]
    
    // Audio analysis (shared with other plugins)
    struct AudioAnalysis: Codable {
        let spectrum: [Float]     // FFT frequency bins
        let waveform: [Float]     // Time-domain samples
        let tempo: Double?        // BPM estimate
        let energy: Float         // Overall loudness 0-1
        let dominantFrequency: Float
    }
    
    // API for other plugins to use audio data
    // GET /api/v1/audio/analysis  (current analysis)
    // WS  /api/v1/audio/stream    (real-time analysis stream)
    
    // Custom shader support
    func loadCustomShader(at path: URL) throws -> VisualizerPreset
}

// Third-party visualizer plugins can implement:
protocol VisualizerPreset {
    var name: String { get }
    func render(analysis: AudioAnalysis, in context: GraphicsContext, size: CGSize)
}
```

---

### 4.7 Meeting Mode Plugin

```swift
struct MeetingModePlugin: NotchPlugin {
    let id = "com.machnotch.meeting"
    
    struct MeetingSession: Codable {
        let id: UUID
        let startTime: Date
        let endTime: Date?
        let calendarEventId: String?
        let actions: [MeetingAction]  // What was auto-enabled
    }
    
    enum MeetingAction: Codable {
        case enabledDND
        case mutedNotifications
        case startedWebcam
        case startedRecording
    }
    
    // Export meeting history
    func exportData(format: ExportFormat) async throws -> Data {
        switch format {
        case .csv:
            return """
            Date,Duration,Actions
            \(sessions.map { "\($0.startTime),\($0.duration),\($0.actions.description)" }.joined(separator: "\n"))
            """.data(using: .utf8)!
        }
    }
    
    // Integration with calendar
    func upcomingMeetings() async -> [CalendarEvent] {
        // Query calendar plugin
        await pluginManager.send(.query("upcoming-events"), to: "com.machnotch.calendar")
    }
}
```

---

## 5. AI Integration (Local-First)

### Philosophy
- **On-device first:** Use Core ML, CreateML for privacy
- **User controls cloud:** Explicit opt-in for cloud AI features
- **Transparent:** Show what data is sent where
- **Exportable models:** Users can export/replace AI models

### 5.1 Clipboard Intelligence (Local)

```swift
struct ClipboardAI {
    // Local Core ML model for classification
    let classifier: ClipboardClassifier  // CreateML text classifier
    
    func classify(_ text: String) -> ClipboardClassification {
        // Runs entirely on-device
        return classifier.predict(text)
    }
    
    enum ClipboardClassification {
        case url(URL)
        case email(String)
        case phone(String)
        case address(String)
        case code(language: String)
        case plainText
    }
    
    func suggestedActions(for classification: ClipboardClassification) -> [QuickAction] {
        switch classification {
        case .url(let url):
            return [.openInBrowser, .addToShelf, .copyAsMarkdownLink]
        case .code(let language):
            return [.formatCode, .runInTerminal, .addToSnippets]
        // ...
        }
    }
}
```

### 5.2 Context Engine (Local)

```swift
struct ContextEngine {
    // Gather context from various sources
    func currentContext() async -> UserContext {
        UserContext(
            activeApp: NSWorkspace.shared.frontmostApplication,
            clipboard: ClipboardManager.shared.latest,
            timeOfDay: Date(),
            calendarContext: await calendarPlugin.upcomingEvents(limit: 3),
            focusMode: await getFocusMode(),
            recentFiles: await getRecentFiles()
        )
    }
    
    // Local rules engine (no AI needed for basic suggestions)
    func suggestions(for context: UserContext) -> [ContextualSuggestion] {
        var suggestions: [ContextualSuggestion] = []
        
        // Rule: Meeting starting soon
        if let meeting = context.upcomingMeeting, meeting.startsIn < .minutes(10) {
            suggestions.append(.joinMeeting(meeting))
        }
        
        // Rule: Coding context
        if context.activeApp?.bundleIdentifier == "com.apple.dt.Xcode" {
            suggestions.append(.openTerminal)
            suggestions.append(.openDocumentation)
        }
        
        return suggestions
    }
}
```

### 5.3 Smart Summaries (Opt-in Cloud)

```swift
struct SmartSummaries {
    enum Provider: String, CaseIterable {
        case local      // Smaller on-device model
        case openai     // GPT API
        case anthropic  // Claude API
        case ollama     // Local Ollama server
        case custom     // User-provided endpoint
    }
    
    var provider: Provider = .local
    var apiEndpoint: URL?  // For custom providers
    
    // User controls what data is sent
    struct SummaryRequest {
        let text: String
        let maxTokens: Int
        let provider: Provider
        
        var privacyNote: String {
            switch provider {
            case .local, .ollama:
                return "Processed entirely on your device"
            case .openai, .anthropic:
                return "Text will be sent to \(provider.rawValue) servers"
            case .custom:
                return "Text will be sent to \(apiEndpoint?.host ?? "custom endpoint")"
            }
        }
    }
    
    func summarize(_ request: SummaryRequest) async throws -> String {
        // Show privacy note before sending
        // Process with chosen provider
    }
}
```

---

## 6. Integration Ecosystem

### 6.1 App Intents (Shortcuts)

```swift
struct OpenNotchIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Notch"
    static var description = IntentDescription("Opens the machNotch panel")
    
    @Parameter(title: "Tab")
    var tab: NotchTab?
    
    func perform() async throws -> some IntentResult {
        await NotchController.shared.open(tab: tab)
        return .result()
    }
}

struct ExportDataIntent: AppIntent {
    static var title: LocalizedStringResource = "Export machNotch Data"
    
    @Parameter(title: "Plugin")
    var plugin: String?
    
    @Parameter(title: "Format")
    var format: ExportFormat
    
    func perform() async throws -> some IntentResult & ReturnsValue<FileEntity> {
        let url = try await PluginManager.shared.exportData(
            plugin: plugin,
            format: format
        )
        return .result(value: FileEntity(url: url))
    }
}

// More intents:
// - AddToShelfIntent
// - CompleteHabitIntent
// - StartPomodoroIntent
// - ToggleMeetingModeIntent
```

### 6.2 URL Scheme

```
machnotch://open                     # Open notch
machnotch://open?tab=calendar        # Open specific tab
machnotch://plugin/habits/complete?id=xxx
machnotch://export?format=json&plugin=all
machnotch://shelf/add?url=file:///path/to/file
```

### 6.3 AppleScript/JXA Support

```applescript
tell application "machNotch"
    open notch
    set current tab to "calendar"
    
    -- Plugin commands
    tell plugin "habits"
        complete habit "Exercise"
    end tell
    
    -- Export
    export all data to "~/Desktop/" as CSV
end tell
```

### 6.4 Raycast Extension

```typescript
// raycast-extension/src/open-notch.ts
import { showHUD } from "@raycast/api";

export default async function Command() {
  const response = await fetch("http://localhost:19384/api/v1/notch/open");
  if (response.ok) {
    await showHUD("Notch opened");
  }
}
```

### 6.5 Browser Extension

```javascript
// For "Send to Shelf" from browser
browser.contextMenus.create({
  id: "send-to-shelf",
  title: "Send to machNotch Shelf",
  contexts: ["link", "image", "selection"]
});

browser.contextMenus.onClicked.addListener(async (info) => {
  await fetch("http://localhost:19384/api/v1/shelf/add", {
    method: "POST",
    body: JSON.stringify({ url: info.linkUrl || info.srcUrl })
  });
});
```

---

## 7. Data Portability Standards

### Export Formats by Plugin

| Plugin | JSON | CSV | iCal | Markdown | HTML |
|--------|------|-----|------|----------|------|
| Habits | ✓ | ✓ | ✓* | ✓ | - |
| Pomodoro | ✓ | ✓ | - | - | - |
| Notes | ✓ | - | - | ✓ | ✓ |
| Clipboard | ✓ | ✓ | - | - | - |
| Calendar | ✓ | - | ✓ | - | - |
| Stats | ✓ | ✓ | - | - | - |

*Habits can export as calendar events for visualization

### Import Support

```swift
protocol ImportablePlugin {
    func supportedImportFormats() -> [ExportFormat]
    func importData(from url: URL, format: ExportFormat) async throws -> ImportResult
    func previewImport(from url: URL) async throws -> ImportPreview
}

struct ImportPreview {
    let itemCount: Int
    let conflicts: [ImportConflict]
    let sample: [Any]  // First few items
}
```

### Sync Provider Protocol

```swift
protocol SyncProvider: Identifiable {
    var id: String { get }
    var name: String { get }
    var icon: Image { get }
    
    func configure() async throws  // OAuth, path selection, etc.
    func push(_ data: Data) async throws
    func pull() async throws -> Data
    func resolveConflict(_ conflict: SyncConflict) async throws
    
    var status: SyncStatus { get }
}

// Built-in providers
struct iCloudSyncProvider: SyncProvider { }
struct FileSystemSyncProvider: SyncProvider { }  // Any folder
struct GitSyncProvider: SyncProvider { }  // Commit on change
struct WebDAVSyncProvider: SyncProvider { }
```

---

## 8. Security & Privacy

### Plugin Sandboxing

```swift
struct PluginPermission: OptionSet {
    static let network = PluginPermission(rawValue: 1 << 0)
    static let fileSystem = PluginPermission(rawValue: 1 << 1)
    static let clipboard = PluginPermission(rawValue: 1 << 2)
    static let notifications = PluginPermission(rawValue: 1 << 3)
    static let calendar = PluginPermission(rawValue: 1 << 4)
    static let microphone = PluginPermission(rawValue: 1 << 5)
    static let camera = PluginPermission(rawValue: 1 << 6)
    static let systemStats = PluginPermission(rawValue: 1 << 7)
}

// Plugins declare permissions, users approve
struct PluginManifest {
    let permissions: [PluginPermission]
    let permissionReasons: [PluginPermission: String]  // Why it needs each
}
```

### Local API Security

```swift
struct LocalAPIConfig {
    var bindAddress: String = "127.0.0.1"  // Local only by default
    var port: UInt16 = 19384
    var requireAuth: Bool = false  // Local doesn't need it
    var authToken: String?  // For remote access if enabled
    var allowedOrigins: [String] = ["*"]  // CORS
    var rateLimiting: RateLimitConfig?
}
```

### Data Encryption

```swift
struct DataEncryption {
    // At-rest encryption for sensitive plugin data
    var encryptionEnabled: Bool = true
    var keychain: KeychainAccess
    
    func encrypt(_ data: Data) throws -> Data
    func decrypt(_ data: Data) throws -> Data
}
```

---

## 9. Implementation Roadmap

### Phase 1: Plugin Foundation (2 weeks)
- [ ] Define `NotchPlugin` protocol
- [ ] Create `PluginManager`
- [ ] Refactor Music as first plugin
- [ ] Refactor Calendar as plugin
- [ ] Refactor Shelf as plugin
- [ ] Basic plugin settings UI

### Phase 2: Data Layer (1 week)
- [ ] Implement `PluginDataStore` protocol
- [ ] Add JSON export for all plugins
- [ ] Add CSV export where applicable
- [ ] Create unified export UI

### Phase 3: Local API (1 week)
- [ ] Implement REST API server
- [ ] Add WebSocket event stream
- [ ] Create CLI tool
- [ ] Document API endpoints

### Phase 4: New Plugins (2 weeks each)
- [ ] Habit Tracker plugin
- [ ] Pomodoro plugin
- [ ] Quick Notes plugin
- [ ] Clipboard History plugin

### Phase 5: Integrations (1 week)
- [ ] App Intents / Shortcuts
- [ ] URL scheme handler
- [ ] AppleScript dictionary

### Phase 6: AI Features (2 weeks)
- [ ] Clipboard classification (local ML)
- [ ] Context engine
- [ ] Optional cloud AI integration

### Phase 7: External Plugins (2 weeks)
- [ ] Plugin packaging format
- [ ] Plugin discovery UI
- [ ] Security review process
- [ ] Documentation for plugin developers

---

## 10. Developer Experience

### Plugin SDK

```bash
# Install plugin development tools
$ brew install machnotch-sdk

# Create new plugin
$ machnotch-sdk create my-plugin
Creating plugin at ./my-plugin...
├── Package.swift
├── Sources/
│   └── MyPlugin/
│       ├── MyPlugin.swift
│       └── Views/
├── Tests/
└── README.md

# Build and test
$ machnotch-sdk build
$ machnotch-sdk test

# Run in dev mode (hot reload)
$ machnotch-sdk dev

# Package for distribution
$ machnotch-sdk package
Created: my-plugin.machplugin
```

### Plugin Documentation Template

```markdown
# My Plugin

## Installation
...

## Features
...

## Data Export
This plugin exports the following data formats:
- JSON: Full data export
- CSV: Tabular data for spreadsheets

## API Endpoints
- `GET /api/v1/my-plugin/data` - Get all data
- `POST /api/v1/my-plugin/action` - Perform action

## Privacy
This plugin:
- ✅ Stores all data locally
- ✅ Never sends data to external servers
- ✅ Supports full data export
```

---

## Summary

**Core Principles:**
1. **Everything is a plugin** - Even built-in features
2. **Your data, your choice** - Export anytime, any format
3. **Local-first** - Data stays on device unless you choose otherwise
4. **Open APIs** - Other apps can integrate freely
5. **No lock-in** - Standard formats, easy migration

This architecture ensures machNotch remains a **platform** that respects user autonomy while enabling a rich ecosystem of extensions and integrations.
---
description: "Git Branching and Deployment Constraints"
activation: "Always On"
---
# Git Flow Rule

For canonical repo policy, read `AGENTS.md`, `repo.yaml`, and `docs/decisions/0001-main-only-branching.md` first.

## Branching Strategy

| Branch | Role | Source | Rules |
|--------|------|--------|-------|
| `main` | Canonical integration branch | Verified local or topic-branch work | Build must be green. |
| `topic/` | Optional short-lived active development | `main` | Naming: `feature/`, `fix/`, `perf/`, `refactor/`. |

## Development Rules

1. **Branching:** `main` is the canonical integration branch. Use short-lived topic branches when useful; do not require a long-lived `dev` branch.
2. **Build Integrity:** Run `/build` (if available) or verify compilation before considering work complete.
3. **Documentation:** Every feature or performance fix must update the relevant PRD under `docs/prds/` and any affected guides or ADRs.
4. **Resilience:** Use /git-flow to automate integration when available.
5. **Commit Shape:** Prefer logical commits. Larger cohesive solo-maintainer commits are acceptable when verified.

## Deployment Flow

1. **Development:** Create branch from `main` → Implement → Verify.
2. **Integration:** Merge topic branch into `main` → Push to origin.
3. **Release:** Tag production-ready milestones from verified `main` commits.

@/docs/prds/machNotch.md
@/Users/larsboes/Developer/mach-mono/.agent/workflows/git-flow.md
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
    let id = "com.machnotch.myplugin"
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
# Agent Guidelines (Centralized)

This directory serves as the **single source of truth** for all agent behavior, architectural rules, and project conventions.

## Index
- [Architecture](ARCHITECTURE.md)
- [Conventions](CONVENTIONS.md)
- [Design](DESIGN.md)
- [Feature Ideas](FEATURE_IDEAS.md)
- [Git Flow](GIT_FLOW.md)
- [Plugin Architecture](plugin-architecture.md)
- [Refactoring Standards](refactoring.md)
- [Skills & Capabilities](SKILLS.md)
- [Source of Truth Policy](source-of-truth.md)
- [Swift Code Quality](swift-code-quality.md)

*Note: All agents (Claude, Gemini, etc.) should treat these files as their primary configuration.*
# Refactoring Rules

Applies to: all files during refactoring work

## File-by-File Approach

When refactoring a file, fix ALL violations in one pass:
1. Remove `.shared` singleton access
2. Replace direct `Defaults[.]` with settings injection
3. Split if > 300 lines
4. Add `@Observable` / `@MainActor` if missing

Don't leave partial fixes — each file should be clean when you're done.

## Dependency Order

Work in tier order to avoid breaking changes:

1. **Tier 1 (Leaf files)** — No downstream dependents, safe to change
2. **Tier 2 (Hub files)** — Change after Tier 1 consumers are clean
3. **Tier 3 (God objects)** — Decompose last

## Extract, Don't Delete

When splitting large files:
1. Create new file with extracted code
2. Update imports in consumers
3. Verify build passes
4. THEN remove from original

## Test After Each File

After completing a file:
```bash
bazel build //Apps/machNotch:machNotch
```

Don't batch multiple files without verifying builds.

## Commit Granularity

One commit per logical unit:
- "refactor: eliminate .shared from VolumeManager" ✓
- "refactor: fix everything" ✗

This makes rollbacks possible if something breaks.
# Skills Usage Rule

> **Purpose:** Ensure available skills are checked and used when working on plans and tasks.

---

## When Working on Plans

Before executing any implementation plan:

1. **Check available skills** in `.agent/skills/` directory
2. **Read the SKILL.md** file for any relevant skill
3. **Follow the skill's instructions** exactly as documented

## Available Skills

| Skill | When to Use |
|-------|-------------|
| `swift-concurrency` | Any work involving async/await, actors, @MainActor, Sendable, or Swift 6 migration |
| `save-context` | Before ending a conversation, to preserve progress for future sessions |

## Skill Activation

Skills are activated by reading their `SKILL.md` file. When a plan references patterns covered by a skill (e.g., "use event bus" or "migrate to @Observable"), check if a relevant skill exists first.

## Plan Integration

Plans in `docs/plans/` may reference skills via:
- `> **For Claude:** Use superpowers:executing-plans to implement this plan`
- Skill-specific patterns (e.g., `@MainActor`, `PluginEventBus`)

Always cross-reference plan requirements with available skills before implementation.
# Source-of-truth map

Claude Code should treat the root docs as canonical:

1. `AGENTS.md` — common AI agent instructions and learned preferences.
2. `repo.yaml` — structured repo facts, product paths, policies, and doc pointers.
3. `docs/README.md` — documentation index.
4. Product-specific instructions such as `Apps/machNotch/CLAUDE.md`.

`.claude/rules/` contains Claude-specific coding rules only. If a repo fact changes, update `repo.yaml` and the relevant Markdown source of truth instead of duplicating the fact here.
# Swift Code Quality Rules

Applies to: `**/*.swift`

## File Size Limits

**Hard limit: 300 lines** — Files exceeding this MUST be split.
**Target: 200 lines** — Prefer smaller, focused files.

When a file approaches 300 lines:
1. Identify cohesive responsibilities
2. Extract into separate files (e.g., `FooViewModel.swift` → `FooViewModel.swift` + `FooViewModelHelpers.swift`)
3. Use extensions in separate files for protocol conformances

## No Singletons in Views or Services

**BANNED patterns:**
```swift
// DON'T - singleton access
@Bindable var coordinator = NotchViewCoordinator.shared
let manager = SomeManager.shared
```

**REQUIRED patterns:**
```swift
// DO - environment injection
@Environment(NotchViewModel.self) private var viewModel
@Environment(\.pluginManager) private var pluginManager

// DO - init injection
init(service: SomeServiceProtocol) { ... }
```

## No Direct Defaults Access

**BANNED:**
```swift
Defaults[.someSetting]
@Default(.someSetting) var setting
```

**REQUIRED:**
```swift
// Use NotchSettings or PluginSettings abstraction
settings.someSetting
@Environment(\.bindableSettings) private var settings
```

Exception: `NotchSettings.swift` is the ONLY file allowed direct Defaults access.

## Observable State

**All observable classes MUST use:**
```swift
@Observable
@MainActor
final class SomeViewModel { ... }
```

**BANNED:**
```swift
class SomeViewModel: ObservableObject {
    @Published var state: State  // OLD pattern
}
```

## Protocol-Based Services

Services MUST be protocol-based for testability:
```swift
// Protocol in separate file
protocol SomeServiceProtocol: Sendable {
    func doThing() async throws
}

// Implementation
final class SomeService: SomeServiceProtocol { ... }
```

## File Organization

Standard order within files:
1. Imports
2. Type declaration with stored properties
3. Initializers
4. Public/internal methods
5. Private methods
6. Extensions (prefer separate files for large conformances)
