//
//  NotchPlugin.swift
//  machNotch
//
//  Core plugin protocol that every plugin must implement.
//

import Combine
import SwiftUI

// MARK: - Core Plugin Protocol

/// The fundamental protocol every plugin must implement.
/// Defines identity, lifecycle, and UI slots.
@MainActor
public protocol NotchPlugin: Identifiable, Observable, AnyObject {
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
    /// - Parameter context: Provides access to services, settings, and event bus
    func activate(context: PluginContext) async throws

    /// Called when plugin is disabled. Clean up resources.
    func deactivate() async

    // MARK: - UI Slots

    associatedtype ClosedContent: View
    associatedtype ExpandedContent: View
    associatedtype SettingsContent: View
    associatedtype MenuBarContent: View

    /// Content shown in the closed notch (compact view)
    @ViewBuilder
    func closedNotchContent() -> ClosedContent

    /// Content shown when notch is expanded (full panel)
    @ViewBuilder
    func expandedPanelContent() -> ExpandedContent

    /// Settings UI for this plugin
    @ViewBuilder
    func settingsContent() -> SettingsContent

    /// Items contributed to the app's menu bar extra dropdown
    @ViewBuilder
    func menuBarView() -> MenuBarContent

    // MARK: - Display Requests

    /// The current request for the plugin to be displayed in the closed notch.
    /// Returns nil if the plugin doesn't need to be shown.
    var displayRequest: DisplayRequest? { get }
}

// MARK: - Display Request Types

public struct DisplayRequest: Equatable, Sendable {
    public let priority: DisplayPriority
    /// Optional context to help the state machine decide (e.g., "music", "timer")
    public let category: DisplayCategory
    /// Optional preferred closed notch height (e.g. teleprompter needs double height for text below camera)
    public let preferredHeight: CGFloat?

    public init(priority: DisplayPriority, category: DisplayCategory, preferredHeight: CGFloat? = nil) {
        self.priority = priority
        self.category = category
        self.preferredHeight = preferredHeight
    }

    public static let music = DisplayCategory(rawValue: "music")
    public static let notification = DisplayCategory(rawValue: "notification")
    public static let utility = DisplayCategory(rawValue: "utility")
    public static let system = DisplayCategory(rawValue: "system")
}

public struct DisplayCategory: RawRepresentable, Equatable, Sendable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public enum DisplayPriority: Int, Comparable, Sendable {
    case background = 0  // Only if nothing else is showing
    case normal = 10  // Standard content (e.g., weather)
    case high = 20  // Active content (e.g., music playing)
    case critical = 30  // Urgent (e.g., battery low)

    public static func < (lhs: DisplayPriority, rhs: DisplayPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Default Implementations

extension NotchPlugin {
    /// Default: no closed notch content
    public func closedNotchContent() -> EmptyView { EmptyView() }

    /// Default: no expanded panel content
    public func expandedPanelContent() -> EmptyView { EmptyView() }

    /// Default: no custom settings (uses auto-generated toggle)
    public func settingsContent() -> EmptyView { EmptyView() }

    /// Default: no menu bar contribution
    public func menuBarView() -> EmptyView { EmptyView() }

    /// Default: no display request
    public var displayRequest: DisplayRequest? { nil }
}

// MARK: - Plugin Metadata

public struct PluginMetadata: Sendable, Hashable {
    public let name: String
    public let description: String
    public let icon: String  // SF Symbol name
    public let version: String
    public let author: String
    public let category: PluginCategory

    public init(
        name: String,
        description: String,
        icon: String,
        version: String = "1.0.0",
        author: String = "machNotch",
        category: PluginCategory = .utilities
    ) {
        self.name = name
        self.description = description
        self.icon = icon
        self.version = version
        self.author = author
        self.category = category
    }
}

public enum PluginCategory: String, CaseIterable, Sendable {
    case media
    case productivity
    case utilities
    case system
    case social

    public var displayName: String {
        rawValue.capitalized
    }

    public var icon: String {
        switch self {
        case .media: return "play.circle"
        case .productivity: return "checkmark.circle"
        case .utilities: return "wrench.and.screwdriver"
        case .system: return "gearshape"
        case .social: return "person.2"
        }
    }
}

// MARK: - Plugin State

public enum PluginState: Sendable, Equatable {
    case inactive
    case activating
    case active
    case error(PluginError)

    public var isActive: Bool {
        if case .active = self { return true }
        return false
    }

    public var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

// MARK: - Plugin Error

public enum PluginError: Error, LocalizedError, Sendable, Equatable {
    case notFound(String)
    case activationFailed(String)
    case permissionDenied(String)
    case invalidState(String)
    case exportFailed(String)
    case serviceUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "Plugin not found: \(id)"
        case .activationFailed(let reason):
            return "Activation failed: \(reason)"
        case .permissionDenied(let permission):
            return "Permission denied: \(permission)"
        case .invalidState(let state):
            return "Invalid state: \(state)"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .serviceUnavailable(let service):
            return "Service unavailable: \(service)"
        }
    }
}

// MARK: - Type Erasure Helper

/// Type-erased wrapper for any NotchPlugin
@MainActor
public struct AnyNotchPlugin: Identifiable {
    public let id: String
    public let underlying: any NotchPlugin
    private let _metadata: () -> PluginMetadata
    private let _isEnabled: () -> Bool
    private let _setEnabled: (Bool) -> Void
    private let _state: () -> PluginState
    private let _activate: (PluginContext) async throws -> Void
    private let _deactivate: () async -> Void
    private let _displayRequest: () -> DisplayRequest?
    private let _closedNotchPosition: () -> ClosedNotchPosition?

    private let _closedNotchContent: () -> AnyView
    private let _expandedPanelContent: () -> AnyView
    private let _settingsContent: () -> AnyView
    private let _menuBarView: () -> AnyView

    public let hasClosedNotchContent: Bool
    public let hasExpandedPanelContent: Bool
    public let hasSettingsContent: Bool
    public let hasMenuBarContent: Bool

    public init<P: NotchPlugin>(_ plugin: P) {
        self.id = plugin.id
        self.underlying = plugin
        self._metadata = { plugin.metadata }
        self._isEnabled = { plugin.isEnabled }
        self._setEnabled = { plugin.isEnabled = $0 }
        self._state = { plugin.state }
        self._activate = { try await plugin.activate(context: $0) }
        self._deactivate = { await plugin.deactivate() }
        self._displayRequest = { plugin.displayRequest }
        // Preserve PositionedPlugin conformance through type erasure
        if let positioned = plugin as? any PositionedPlugin {
            self._closedNotchPosition = { positioned.closedNotchPosition }
        } else {
            self._closedNotchPosition = { nil }
        }

        self._closedNotchContent = { AnyView(plugin.closedNotchContent()) }
        self._expandedPanelContent = { AnyView(plugin.expandedPanelContent()) }
        self._settingsContent = { AnyView(plugin.settingsContent()) }
        self._menuBarView = { AnyView(plugin.menuBarView()) }

        self.hasClosedNotchContent = type(of: plugin.closedNotchContent()) != EmptyView.self
        self.hasExpandedPanelContent = type(of: plugin.expandedPanelContent()) != EmptyView.self
        self.hasSettingsContent = type(of: plugin.settingsContent()) != EmptyView.self
        self.hasMenuBarContent = type(of: plugin.menuBarView()) != EmptyView.self
    }

    public var metadata: PluginMetadata { _metadata() }
    public var isEnabled: Bool {
        get { _isEnabled() }
        nonmutating set { _setEnabled(newValue) }
    }
    public var state: PluginState { _state() }

    public func activate(context: PluginContext) async throws {
        try await _activate(context)
    }

    public func deactivate() async {
        await _deactivate()
    }

    public var displayRequest: DisplayRequest? { _displayRequest() }
    public var closedNotchPosition: ClosedNotchPosition? { _closedNotchPosition() }

    public func closedNotchContent() -> AnyView { _closedNotchContent() }
    public func expandedPanelContent() -> AnyView { _expandedPanelContent() }
    public func settingsContent() -> AnyView { _settingsContent() }
    public func menuBarView() -> AnyView { _menuBarView() }
}
