//
//  NotchPlugin.swift
//  boringNotch
//
//  Core plugin protocol that every plugin must implement.
//

import SwiftUI
import Combine

// MARK: - Core Plugin Protocol

/// The fundamental protocol every plugin must implement.
/// Defines identity, lifecycle, and UI slots.
@MainActor
protocol NotchPlugin: Identifiable, Observable, AnyObject {
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

struct DisplayRequest: Equatable, Sendable {
    let priority: DisplayPriority
    /// Optional context to help the state machine decide (e.g., "music", "timer")
    let category: DisplayCategory
    /// Optional preferred closed notch height (e.g. teleprompter needs double height for text below camera)
    let preferredHeight: CGFloat?

    init(priority: DisplayPriority, category: DisplayCategory, preferredHeight: CGFloat? = nil) {
        self.priority = priority
        self.category = category
        self.preferredHeight = preferredHeight
    }

    static let music = DisplayCategory(rawValue: "music")
    static let notification = DisplayCategory(rawValue: "notification")
    static let utility = DisplayCategory(rawValue: "utility")
    static let system = DisplayCategory(rawValue: "system")
}

struct DisplayCategory: RawRepresentable, Equatable, Sendable {
    let rawValue: String
}

enum DisplayPriority: Int, Comparable, Sendable {
    case background = 0    // Only if nothing else is showing
    case normal = 10       // Standard content (e.g., weather)
    case high = 20         // Active content (e.g., music playing)
    case critical = 30     // Urgent (e.g., battery low)

    static func < (lhs: DisplayPriority, rhs: DisplayPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Default Implementations

extension NotchPlugin {
    /// Default: no closed notch content
    func closedNotchContent() -> EmptyView { EmptyView() }

    /// Default: no expanded panel content
    func expandedPanelContent() -> EmptyView { EmptyView() }

    /// Default: no custom settings (uses auto-generated toggle)
    func settingsContent() -> EmptyView { EmptyView() }

    /// Default: no menu bar contribution
    func menuBarView() -> EmptyView { EmptyView() }

    /// Default: no display request
    var displayRequest: DisplayRequest? { nil }
}

// MARK: - Plugin Metadata

struct PluginMetadata: Sendable, Hashable {
    let name: String
    let description: String
    let icon: String  // SF Symbol name
    let version: String
    let author: String
    let category: PluginCategory

    init(
        name: String,
        description: String,
        icon: String,
        version: String = "1.0.0",
        author: String = "boringNotch",
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

enum PluginCategory: String, CaseIterable, Sendable {
    case media
    case productivity
    case utilities
    case system
    case social

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
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

enum PluginState: Sendable, Equatable {
    case inactive
    case activating
    case active
    case error(PluginError)

    var isActive: Bool {
        if case .active = self { return true }
        return false
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

// MARK: - Plugin Error

enum PluginError: Error, LocalizedError, Sendable, Equatable {
    case notFound(String)
    case activationFailed(String)
    case permissionDenied(String)
    case invalidState(String)
    case exportFailed(String)
    case serviceUnavailable(String)

    var errorDescription: String? {
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
struct AnyNotchPlugin: Identifiable {
    let id: String
    let underlying: any NotchPlugin
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

    let hasClosedNotchContent: Bool
    let hasExpandedPanelContent: Bool
    let hasSettingsContent: Bool
    let hasMenuBarContent: Bool

    init<P: NotchPlugin>(_ plugin: P) {
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

    var metadata: PluginMetadata { _metadata() }
    var isEnabled: Bool {
        get { _isEnabled() }
        nonmutating set { _setEnabled(newValue) }
    }
    var state: PluginState { _state() }

    func activate(context: PluginContext) async throws {
        try await _activate(context)
    }

    func deactivate() async {
        await _deactivate()
    }

    var displayRequest: DisplayRequest? { _displayRequest() }
    var closedNotchPosition: ClosedNotchPosition? { _closedNotchPosition() }
    
    func closedNotchContent() -> AnyView { _closedNotchContent() }
    func expandedPanelContent() -> AnyView { _expandedPanelContent() }
    func settingsContent() -> AnyView { _settingsContent() }
    func menuBarView() -> AnyView { _menuBarView() }
}
