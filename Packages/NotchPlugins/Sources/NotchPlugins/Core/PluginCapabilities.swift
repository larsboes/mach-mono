//
//  PluginCapabilities.swift
//  machNotch
//
//  Capability protocols that plugins can adopt for additional functionality.
//  These are mix-ins: adopt what you need.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Playable Plugin

/// Plugin can control media playback
@MainActor
public protocol PlayablePlugin: NotchPlugin {
    /// Whether media is currently playing
    var isPlaying: Bool { get }

    /// Current now playing information
    var nowPlaying: NowPlayingInfo? { get }

    /// Playback progress (0.0 - 1.0)
    var playbackProgress: Double { get }

    /// Start playback
    func play() async

    /// Pause playback
    func pause() async

    /// Toggle play/pause state
    func togglePlayPause() async

    /// Skip to next track
    func next() async

    /// Go to previous track
    func previous() async

    /// Seek to position (0.0 - 1.0)
    func seek(to progress: Double) async
}

// Default implementations
extension PlayablePlugin {
    public func togglePlayPause() async {
        if isPlaying {
            await pause()
        } else {
            await play()
        }
    }
}

// MARK: - Exportable Plugin

/// Plugin can export its data in various formats
@MainActor
public protocol ExportablePlugin: NotchPlugin {
    /// Formats this plugin supports for export
    var supportedExportFormats: [ExportFormat] { get }

    /// Export data in the specified format
    func exportData(format: ExportFormat) async throws -> Data
}

public enum ExportError: Error, LocalizedError {
    case unsupportedFormat(ExportFormat)
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let f): return "Export format '\(f.rawValue)' is not supported by this plugin."
        case .encodingFailed: return "Failed to encode export data."
        }
    }
}

public enum ExportFormat: String, CaseIterable, Sendable {
    case json
    case csv
    case xml
    case ical
    case markdown
    case html

    public var fileExtension: String { rawValue }

    public var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        case .xml: return "application/xml"
        case .ical: return "text/calendar"
        case .markdown: return "text/markdown"
        case .html: return "text/html"
        }
    }

    public var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .xml: return "XML"
        case .ical: return "iCalendar"
        case .markdown: return "Markdown"
        case .html: return "HTML"
        }
    }
}

// MARK: - Data Storing Plugin

/// Plugin stores persistent data that can be saved/loaded
@MainActor
public protocol DataStoringPlugin: NotchPlugin {
    associatedtype DataModel: Codable & Sendable

    /// The plugin's data
    var data: DataModel { get }

    /// Persist data to storage
    func save() async throws

    /// Load data from storage
    func load() async throws
}

// MARK: - Drop Receiving Plugin

/// Plugin can receive dropped items
@MainActor
public protocol DropReceivingPlugin: NotchPlugin {
    /// Types of items this plugin accepts
    var acceptedDropTypes: [UTType] { get }

    /// Handle dropped items
    /// - Returns: true if the drop was handled successfully
    func handleDrop(_ providers: [NSItemProvider]) async -> Bool
}

// MARK: - Notifying Plugin

/// Plugin can send notifications to the user
@MainActor
public protocol NotifyingPlugin: NotchPlugin {
    /// Pending notifications that should be shown
    func pendingNotifications() -> [PluginNotification]

    /// Clear a specific notification
    func clearNotification(_ id: String)

    /// Clear all notifications
    func clearAllNotifications()
}

public struct PluginNotification: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let icon: String?
    public let timestamp: Date
    public let priority: NotificationPriority
    public let action: NotificationAction?

    public init(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        icon: String? = nil,
        timestamp: Date = Date(),
        priority: NotificationPriority = .normal,
        action: NotificationAction? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.icon = icon
        self.timestamp = timestamp
        self.priority = priority
        self.action = action
    }
}

public enum NotificationPriority: Int, Sendable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    public static func < (lhs: NotificationPriority, rhs: NotificationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct NotificationAction: Sendable {
    public let label: String
    public let handler: @Sendable () async -> Void

    public init(label: String, handler: @escaping @Sendable () async -> Void) {
        self.label = label
        self.handler = handler
    }
}

// MARK: - Positioned Plugin

/// Plugin shows content in closed notch at a specific position
@MainActor
public protocol PositionedPlugin: NotchPlugin {
    /// Where this plugin's content appears in the closed notch
    var closedNotchPosition: ClosedNotchPosition { get }
}

public enum ClosedNotchPosition: Sendable, Equatable {
    case left
    case center
    case right
    case farRight  // After standard right content (e.g., battery)

    /// Replace a built-in system element
    case replacing(SystemElement)

    public enum SystemElement: String, Sendable {
        case battery
        case time
        case none
    }
}

// MARK: - Configurable Plugin

/// Plugin has user-configurable settings beyond the basic enable/disable
@MainActor
public protocol ConfigurablePlugin: NotchPlugin {
    /// Whether the plugin has pending configuration (e.g., needs API key)
    var needsConfiguration: Bool { get }

    /// Open the configuration UI
    func openConfiguration()
}

// MARK: - Searchable Plugin

/// Plugin content can be searched
@MainActor
public protocol SearchablePlugin: NotchPlugin {
    /// Search the plugin's content
    func search(query: String) async -> [SearchResult]
}

public struct SearchResult: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let icon: String?
    public let action: @Sendable () async -> Void

    public init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        action: @escaping @Sendable () async -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.action = action
    }
}

// MARK: - Supporting Types

public struct NowPlayingInfo: Sendable, Equatable {
    public let track: TrackInfo
    public let artwork: NSImage?
    public let progress: Double
    public let isPlaying: Bool

    public init(track: TrackInfo, artwork: NSImage?, progress: Double, isPlaying: Bool) {
        self.track = track
        self.artwork = artwork
        self.progress = progress
        self.isPlaying = isPlaying
    }

    public static func == (lhs: NowPlayingInfo, rhs: NowPlayingInfo) -> Bool {
        lhs.track == rhs.track && lhs.progress == rhs.progress && lhs.isPlaying == rhs.isPlaying
    }
}

// Note: TrackInfo is defined in Services/MusicServiceProtocol.swift
// Note: PlaybackState and RepeatMode are defined in models/PlaybackState.swift
// These types are intentionally NOT redefined here to avoid conflicts.
