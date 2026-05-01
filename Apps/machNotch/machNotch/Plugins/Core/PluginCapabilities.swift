//
//  PluginCapabilities.swift
//  boringNotch
//
//  Capability protocols that plugins can adopt for additional functionality.
//  These are mix-ins: adopt what you need.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Playable Plugin

/// Plugin can control media playback
@MainActor
protocol PlayablePlugin: NotchPlugin {
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
    func togglePlayPause() async {
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
protocol ExportablePlugin: NotchPlugin {
    /// Formats this plugin supports for export
    var supportedExportFormats: [ExportFormat] { get }

    /// Export data in the specified format
    func exportData(format: ExportFormat) async throws -> Data
}

enum ExportError: Error, LocalizedError {
    case unsupportedFormat(ExportFormat)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let f): return "Export format '\(f.rawValue)' is not supported by this plugin."
        case .encodingFailed: return "Failed to encode export data."
        }
    }
}

enum ExportFormat: String, CaseIterable, Sendable {
    case json
    case csv
    case xml
    case ical
    case markdown
    case html

    var fileExtension: String { rawValue }

    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        case .xml: return "application/xml"
        case .ical: return "text/calendar"
        case .markdown: return "text/markdown"
        case .html: return "text/html"
        }
    }

    var displayName: String {
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
protocol DataStoringPlugin: NotchPlugin {
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
protocol DropReceivingPlugin: NotchPlugin {
    /// Types of items this plugin accepts
    var acceptedDropTypes: [UTType] { get }

    /// Handle dropped items
    /// - Returns: true if the drop was handled successfully
    func handleDrop(_ providers: [NSItemProvider]) async -> Bool
}

// MARK: - Notifying Plugin

/// Plugin can send notifications to the user
@MainActor
protocol NotifyingPlugin: NotchPlugin {
    /// Pending notifications that should be shown
    func pendingNotifications() -> [PluginNotification]

    /// Clear a specific notification
    func clearNotification(_ id: String)

    /// Clear all notifications
    func clearAllNotifications()
}

struct PluginNotification: Identifiable, Sendable {
    let id: String
    let title: String
    let body: String
    let icon: String?
    let timestamp: Date
    let priority: NotificationPriority
    let action: NotificationAction?

    init(
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

enum NotificationPriority: Int, Sendable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    static func < (lhs: NotificationPriority, rhs: NotificationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct NotificationAction: Sendable {
    let label: String
    let handler: @Sendable () async -> Void

    init(label: String, handler: @escaping @Sendable () async -> Void) {
        self.label = label
        self.handler = handler
    }
}

// MARK: - Positioned Plugin

/// Plugin shows content in closed notch at a specific position
@MainActor
protocol PositionedPlugin: NotchPlugin {
    /// Where this plugin's content appears in the closed notch
    var closedNotchPosition: ClosedNotchPosition { get }
}

enum ClosedNotchPosition: Sendable, Equatable {
    case left
    case center
    case right
    case farRight  // After standard right content (e.g., battery)

    /// Replace a built-in system element
    case replacing(SystemElement)

    enum SystemElement: String, Sendable {
        case battery
        case time
        case none
    }
}

// MARK: - Configurable Plugin

/// Plugin has user-configurable settings beyond the basic enable/disable
@MainActor
protocol ConfigurablePlugin: NotchPlugin {
    /// Whether the plugin has pending configuration (e.g., needs API key)
    var needsConfiguration: Bool { get }

    /// Open the configuration UI
    func openConfiguration()
}

// MARK: - Searchable Plugin

/// Plugin content can be searched
@MainActor
protocol SearchablePlugin: NotchPlugin {
    /// Search the plugin's content
    func search(query: String) async -> [SearchResult]
}

struct SearchResult: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String?
    let action: @Sendable () async -> Void

    init(
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

struct NowPlayingInfo: Sendable, Equatable {
    let track: TrackInfo
    let artwork: NSImage?
    let progress: Double
    let isPlaying: Bool

    static func == (lhs: NowPlayingInfo, rhs: NowPlayingInfo) -> Bool {
        lhs.track == rhs.track &&
        lhs.progress == rhs.progress &&
        lhs.isPlaying == rhs.isPlaying
    }
}

// Note: TrackInfo is defined in Services/MusicServiceProtocol.swift
// Note: PlaybackState and RepeatMode are defined in models/PlaybackState.swift
// These types are intentionally NOT redefined here to avoid conflicts.
