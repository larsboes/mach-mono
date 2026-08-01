//
//  PluginEventBus.swift
//  machNotch
//
//  Central event bus for inter-plugin communication.
//  Enables loose coupling between plugins.
//

import Combine
import Foundation

// MARK: - Plugin Event Bus

/// Central hub for inter-plugin communication.
/// Plugins emit events and subscribe to events from other plugins.
@MainActor
public final class PluginEventBus: Observable {
    private var cancellables = Set<AnyCancellable>()
    private let eventSubject = PassthroughSubject<any PluginEvent, Never>()

    /// Stream of all events
    public var events: AnyPublisher<any PluginEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    public init() {}

    // MARK: - Emitting Events

    /// Emit an event to all subscribers
    public func emit(_ event: any PluginEvent) {
        eventSubject.send(event)
    }

    // MARK: - Subscribing to Events

    /// Subscribe to all events of a specific type.
    /// Handler executes synchronously on MainActor (no Task hop) since
    /// emit() is MainActor-isolated and PassthroughSubject delivers synchronously.
    public func subscribe<T: PluginEvent>(
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
    public func subscribe(
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
    public func subscribe(
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
public protocol PluginEvent: Sendable {
    /// Type of event for filtering
    var type: PluginEventType { get }

    /// ID of the plugin that emitted this event
    var sourcePluginId: String { get }

    /// When the event occurred
    var timestamp: Date { get }
}

// MARK: - Event Types

public enum PluginEventType: String, Sendable, Hashable {
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

    // Pomodoro events
    case pomodoroPhaseChanged

    // Generic
    case custom
}

// MARK: - Generic Event

/// Simple event for cases where a full custom type isn't needed
public struct GenericPluginEvent: PluginEvent {
    public let type: PluginEventType
    public let sourcePluginId: String
    public let timestamp: Date

    public init(
        type: PluginEventType,
        sourcePluginId: String,
        timestamp: Date = Date()
    ) {
        self.type = type
        self.sourcePluginId = sourcePluginId
        self.timestamp = timestamp
    }
}

/// Event requesting a sneak peek
public struct SneakPeekRequestedEvent: PluginEvent {
    public let type = PluginEventType.sneakPeekRequested
    public let sourcePluginId: String
    public let timestamp = Date()
    public let request: SneakPeekRequest

    public init(sourcePluginId: String, request: SneakPeekRequest) {
        self.sourcePluginId = sourcePluginId
        self.request = request
    }
}

// MARK: - Concrete Events

/// Music playback changed event
public struct MusicPlaybackChangedEvent: PluginEvent {
    public let type: PluginEventType
    public let sourcePluginId: String
    public let timestamp: Date
    public let isPlaying: Bool
    public let track: TrackInfo?

    public init(isPlaying: Bool, track: TrackInfo?) {
        self.type = isPlaying ? .musicPlaybackStarted : .musicPlaybackPaused
        self.sourcePluginId = PluginID.music
        self.timestamp = Date()
        self.isPlaying = isPlaying
        self.track = track
    }
}

/// Music track changed event
public struct MusicTrackChangedEvent: PluginEvent {
    public let type = PluginEventType.musicTrackChanged
    public let sourcePluginId: String
    public let timestamp = Date()
    public let previousTrack: TrackInfo?
    public let newTrack: TrackInfo?

    public init(previousTrack: TrackInfo?, newTrack: TrackInfo?) {
        self.sourcePluginId = PluginID.music
        self.previousTrack = previousTrack
        self.newTrack = newTrack
    }
}

/// Calendar event starting soon
public struct CalendarEventStartingSoonEvent: PluginEvent {
    public let type = PluginEventType.calendarEventStartingSoon
    public let sourcePluginId: String
    public let timestamp = Date()
    public let eventId: String
    public let eventTitle: String
    public let startsIn: TimeInterval

    public init(eventId: String, eventTitle: String, startsIn: TimeInterval) {
        self.sourcePluginId = PluginID.calendar
        self.eventId = eventId
        self.eventTitle = eventTitle
        self.startsIn = startsIn
    }
}

/// Shelf item added event
public struct ShelfItemAddedEvent: PluginEvent {
    public let type = PluginEventType.shelfItemAdded
    public let sourcePluginId: String
    public let timestamp = Date()
    public var itemId: UUID
    public var itemDisplayName: String

    public init(itemId: UUID, itemDisplayName: String) {
        self.sourcePluginId = PluginID.shelf
        self.itemId = itemId
        self.itemDisplayName = itemDisplayName
    }
}

/// Battery state changed event
public struct BatteryStateChangedEvent: PluginEvent {
    public let type: PluginEventType
    public let sourcePluginId: String
    public let timestamp = Date()
    public let level: Double
    public let isCharging: Bool

    public init(level: Double, isCharging: Bool, levelChanged: Bool) {
        self.sourcePluginId = PluginID.battery
        self.type = levelChanged ? .batteryLevelChanged : .batteryChargingStateChanged
        self.level = level
        self.isCharging = isCharging
    }
}

/// Pomodoro phase changed event
public struct PomodoroPhaseChangedEvent: PluginEvent {
    public let type: PluginEventType = .pomodoroPhaseChanged
    public let sourcePluginId: String
    public let timestamp = Date()
    public let isRunning: Bool
    public let sessionType: String // "work", "shortBreak", "longBreak"
    public let timeRemaining: TimeInterval

    public init(isRunning: Bool, sessionType: String, timeRemaining: TimeInterval) {
        self.sourcePluginId = PluginID.pomodoro
        self.isRunning = isRunning
        self.sessionType = sessionType
        self.timeRemaining = timeRemaining
    }
}

/// Notch state changed event
/// Note: Uses existing NotchDisplayState from NotchStateMachine.swift
public struct NotchStateChangedEvent: PluginEvent {
    public let type: PluginEventType
    public let sourcePluginId: String
    public let timestamp = Date()
    public let state: NotchDisplayState

    public init(state: NotchDisplayState) {
        self.sourcePluginId = PluginID.System.core
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
public struct HUDValueChangeEvent: PluginEvent {
    public let type: PluginEventType = .custom
    public let sourcePluginId: String
    public let timestamp = Date()
    public let hudType: SneakContentType
    public let newValue: CGFloat
    
    public init(sourcePluginId: String, hudType: SneakContentType, newValue: CGFloat) {
        self.sourcePluginId = sourcePluginId
        self.hudType = hudType
        self.newValue = newValue
    }
}
