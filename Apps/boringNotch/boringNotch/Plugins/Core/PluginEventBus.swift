//
//  PluginEventBus.swift
//  boringNotch
//
//  Central event bus for inter-plugin communication.
//  Enables loose coupling between plugins.
//

import Foundation
import Combine

// MARK: - Plugin Event Bus

/// Central hub for inter-plugin communication.
/// Plugins emit events and subscribe to events from other plugins.
@MainActor
final class PluginEventBus: Observable {
    private var cancellables = Set<AnyCancellable>()
    private let eventSubject = PassthroughSubject<any PluginEvent, Never>()

    /// Stream of all events
    var events: AnyPublisher<any PluginEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    init() {}

    // MARK: - Emitting Events

    /// Emit an event to all subscribers
    func emit(_ event: any PluginEvent) {
        eventSubject.send(event)
    }

    /// Emit a simple event with just a type
    func emit(_ type: PluginEventType, from pluginId: String, data: [String: any Sendable] = [:]) {
        let event = GenericPluginEvent(type: type, sourcePluginId: pluginId, data: data)
        eventSubject.send(event)
    }

    // MARK: - Subscribing to Events

    /// Subscribe to all events of a specific type.
    /// Handler executes synchronously on MainActor (no Task hop) since
    /// emit() is MainActor-isolated and PassthroughSubject delivers synchronously.
    func subscribe<T: PluginEvent>(
        to eventType: T.Type,
        handler: @escaping @MainActor (T) -> Void
    ) -> AnyCancellable {
        events
            .compactMap { $0 as? T }
            .sink { event in
                MainActor.assumeIsolated {
                    handler(event)
                }
            }
    }

    /// Subscribe to events from a specific plugin
    func subscribe(
        from pluginId: String,
        handler: @escaping @MainActor (any PluginEvent) -> Void
    ) -> AnyCancellable {
        events
            .filter { $0.sourcePluginId == pluginId }
            .sink { event in
                MainActor.assumeIsolated {
                    handler(event)
                }
            }
    }

    /// Subscribe to events of a specific type string
    func subscribe(
        toType type: PluginEventType,
        handler: @escaping @MainActor (any PluginEvent) -> Void
    ) -> AnyCancellable {
        events
            .filter { $0.type == type }
            .sink { event in
                MainActor.assumeIsolated {
                    handler(event)
                }
            }
    }
}

// MARK: - Plugin Event Protocol

/// Base protocol for all plugin events
protocol PluginEvent: Sendable {
    /// Type of event for filtering
    var type: PluginEventType { get }

    /// ID of the plugin that emitted this event
    var sourcePluginId: String { get }

    /// When the event occurred
    var timestamp: Date { get }
}

// MARK: - Event Types

enum PluginEventType: String, Sendable, Hashable {
    // Lifecycle events
    case pluginActivated
    case pluginDeactivated
    case pluginError

    // Music events
    case musicPlaybackStarted
    case musicPlaybackPaused
    case musicPlaybackStopped
    case musicTrackChanged

    // Calendar events
    case calendarEventStartingSoon
    case calendarEventStarted
    case calendarEventEnded
    case calendarEventsRefreshed

    // Shelf events
    case shelfItemAdded
    case shelfItemRemoved
    case shelfCleared

    // System events
    case batteryLevelChanged
    case batteryChargingStateChanged
    case volumeChanged
    case brightnessChanged

    // Notch events
    case notchOpened
    case notchClosed
    case notchExpanded
    case sneakPeekRequested

    // Generic
    case custom
}

// MARK: - Generic Event

/// Simple event for cases where a full custom type isn't needed
struct GenericPluginEvent: PluginEvent {
    let type: PluginEventType
    let sourcePluginId: String
    let timestamp: Date
    let data: [String: any Sendable]

    init(
        type: PluginEventType,
        sourcePluginId: String,
        timestamp: Date = Date(),
        data: [String: any Sendable] = [:]
    ) {
        self.type = type
        self.sourcePluginId = sourcePluginId
        self.timestamp = timestamp
        self.data = data
    }
}

/// Event requesting a sneak peek
struct SneakPeekRequestedEvent: PluginEvent {
    let type = PluginEventType.sneakPeekRequested
    let sourcePluginId: String
    let timestamp = Date()
    let request: SneakPeekRequest
    
    init(sourcePluginId: String, request: SneakPeekRequest) {
        self.sourcePluginId = sourcePluginId
        self.request = request
    }
}

// MARK: - Concrete Events

/// Music playback changed event
struct MusicPlaybackChangedEvent: PluginEvent {
    let type: PluginEventType
    let sourcePluginId: String
    let timestamp: Date
    let isPlaying: Bool
    let track: TrackInfo?

    init(isPlaying: Bool, track: TrackInfo?) {
        self.type = isPlaying ? .musicPlaybackStarted : .musicPlaybackPaused
        self.sourcePluginId = PluginID.music
        self.timestamp = Date()
        self.isPlaying = isPlaying
        self.track = track
    }
}

/// Music track changed event
struct MusicTrackChangedEvent: PluginEvent {
    let type = PluginEventType.musicTrackChanged
    let sourcePluginId = PluginID.music
    let timestamp = Date()
    let previousTrack: TrackInfo?
    let newTrack: TrackInfo?

    init(previousTrack: TrackInfo?, newTrack: TrackInfo?) {
        self.previousTrack = previousTrack
        self.newTrack = newTrack
    }
}

/// Calendar event starting soon
struct CalendarEventStartingSoonEvent: PluginEvent {
    let type = PluginEventType.calendarEventStartingSoon
    let sourcePluginId = PluginID.calendar
    let timestamp = Date()
    let event: EventModel
    let startsIn: TimeInterval

    init(event: EventModel, startsIn: TimeInterval) {
        self.event = event
        self.startsIn = startsIn
    }
}

/// Shelf item added event
struct ShelfItemAddedEvent: PluginEvent {
    let type = PluginEventType.shelfItemAdded
    let sourcePluginId = PluginID.shelf
    let timestamp = Date()
    let item: ShelfItem

    init(item: ShelfItem) {
        self.item = item
    }
}

/// Battery state changed event
struct BatteryStateChangedEvent: PluginEvent {
    let type: PluginEventType
    let sourcePluginId = PluginID.battery
    let timestamp = Date()
    let level: Double
    let isCharging: Bool

    init(level: Double, isCharging: Bool, levelChanged: Bool) {
        self.type = levelChanged ? .batteryLevelChanged : .batteryChargingStateChanged
        self.level = level
        self.isCharging = isCharging
    }
}

/// Notch state changed event
/// Note: Uses existing NotchDisplayState from NotchStateMachine.swift
struct NotchStateChangedEvent: PluginEvent {
    let type: PluginEventType
    let sourcePluginId = PluginID.System.core
    let timestamp = Date()
    let state: NotchDisplayState

    init(state: NotchDisplayState) {
        // Map the actual NotchDisplayState cases to event types
        switch state {
        case .closed:
            self.type = .notchClosed
        case .open:
            self.type = .notchOpened
        case .helloAnimation, .sneakPeek, .expanding:
            // These are transitional states, treat as expanded
            self.type = .notchExpanded
        }
        self.state = state
    }
}

/// Event emitted when HUD UI adjusts a system value (volume/brightness).
/// Handled by the Application layer to route to the appropriate service.
struct HUDValueChangeEvent: PluginEvent {
    let type: PluginEventType = .custom
    let sourcePluginId: String
    let timestamp = Date()
    let hudType: SneakContentType
    let newValue: CGFloat
}
