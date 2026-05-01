# boringNotch Plugin Architecture

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
                              │  boringNotchApp │
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
    /// Unique reverse-DNS identifier (e.g., "com.boringnotch.music")
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
struct boringNotchApp: App {
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
        migrateKey(from: .showMusicLiveActivity, to: "plugin.com.boringnotch.music.showLiveActivity")
        migrateKey(from: .enableSneakPeek, to: "plugin.com.boringnotch.music.enableSneakPeek")

        // Calendar plugin settings
        migrateKey(from: .showCalendar, to: "plugin.com.boringnotch.calendar.enabled")

        // Shelf plugin settings
        migrateKey(from: .boringShelf, to: "plugin.com.boringnotch.shelf.enabled")

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
    let sourcePluginId = "com.boringnotch.music"
    let timestamp = Date()
    let isPlaying: Bool
    let track: TrackInfo?
}

struct CalendarEventStartingSoonEvent: PluginEvent {
    let sourcePluginId = "com.boringnotch.calendar"
    let timestamp = Date()
    let event: CalendarEvent
    let startsIn: TimeInterval
}

struct ShelfItemAddedEvent: PluginEvent {
    let sourcePluginId = "com.boringnotch.shelf"
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
boringNotch/
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

*This architecture enables boringNotch to evolve from a monolithic app to a plugin platform while maintaining stability during the transition.*
