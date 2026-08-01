//
//  PluginManager.swift
//  machNotch
//
//  Central registry and lifecycle manager for all plugins.
//

import Combine
import Foundation

// MARK: - Plugin Manager

/// Central registry for all plugins.
/// Manages plugin lifecycle, provides access to plugins for views,
/// and handles inter-plugin communication.
@MainActor
@Observable
public final class PluginManager {
    // MARK: - Properties

    /// Metadata-first plugin registrations.
    var descriptors: [String: PluginDescriptor] = [:]

    /// Instantiated plugins, created on first use.
    var plugins: [String: AnyNotchPlugin] = [:]

    /// Enabled state for descriptor-only plugins.
    var pluginEnabledState: [String: Bool] = [:]

    /// Plugin activation order
    var pluginOrder: [String] = []

    /// Service container for dependency injection
    public let services: any NotchServiceProvider

    /// Incremented each time a plugin activates or deactivates.
    /// ContentView observes this to re-evaluate the state machine after plugin lifecycle changes.
    private(set) var pluginActivationGeneration: Int = 0

    /// Event bus for inter-plugin communication
    public let eventBus: PluginEventBus

    /// App state provider
    private let appState: AppStateProviding

    /// Cancellables for subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    /// All registered plugin IDs
    public var allPluginIds: [String] {
        pluginOrder
    }

    /// All instantiated plugins (ordered). Use `allPluginSummaries` for metadata-only listing.
    public var allPlugins: [AnyNotchPlugin] {
        pluginOrder.compactMap { plugins[$0] }
    }

    /// All registered plugin summaries (ordered), without forcing construction.
    public var allPluginSummaries: [PluginSummary] {
        pluginOrder.compactMap { summary(id: $0) }
    }

    /// All active (enabled and activated) plugins
    public var activePlugins: [AnyNotchPlugin] {
        pluginOrder
            .compactMap { plugins[$0] }
            .filter { $0.isEnabled && $0.state.isActive }
    }

    /// All enabled plugins (may still be activating)
    public var enabledPlugins: [AnyNotchPlugin] {
        pluginOrder
            .compactMap { plugins[$0] }
            .filter { $0.isEnabled }
    }

    // MARK: - Initialization

    /// App-wide media settings, forwarded to plugin contexts
    private let mediaSettings: any MediaSettings

    public init(
        services: any NotchServiceProvider,
        eventBus: PluginEventBus,
        appState: AppStateProviding,
        mediaSettings: any MediaSettings,
        coordinator: any NotchAnimationStateProviding,
        builtInDescriptors: [PluginDescriptor] = [],
        builtInPlugins: [any NotchPlugin] = []
    ) {
        self.services = services
        self.eventBus = eventBus
        self.appState = appState
        self.mediaSettings = mediaSettings

        // Inject shelf service into coordinator
        coordinator.shelfService = services.shelf

        // Register built-in descriptors without constructing plugin instances.
        for descriptor in builtInDescriptors {
            registerDescriptor(descriptor)
        }

        // Register explicit plugin instances for tests/external callers.
        for plugin in builtInPlugins {
            registerPlugin(plugin)
        }
    }

    // MARK: - Plugin Lifecycle

    /// Enable and activate a plugin
    public func enablePlugin(_ id: String) async throws {
        let plugin = try instantiatePlugin(id: id)

        guard !plugin.state.isActive else { return }

        let context = PluginContext(
            settings: PluginSettings(pluginId: id),
            services: services,
            eventBus: eventBus,
            appState: appState,
            mediaSettings: mediaSettings
        )

        let wasEnabled = plugin.isEnabled
        do {
            plugin.isEnabled = true
            try await plugin.activate(context: context)
            pluginEnabledState[id] = true
            pluginActivationGeneration += 1
            eventBus.emit(GenericPluginEvent(type: .pluginActivated, sourcePluginId: id))
        } catch {
            plugin.isEnabled = wasEnabled
            pluginEnabledState[id] = wasEnabled
            throw PluginError.activationFailed(error.localizedDescription)
        }
    }

    /// Disable and deactivate a plugin
    public func disablePlugin(_ id: String) async {
        guard descriptors[id] != nil || plugins[id] != nil else { return }

        pluginEnabledState[id] = false
        guard let plugin = plugins[id] else { return }

        await plugin.deactivate()
        plugin.isEnabled = false
        pluginActivationGeneration += 1
        eventBus.emit(GenericPluginEvent(type: .pluginDeactivated, sourcePluginId: id))
    }

    /// Toggle plugin enabled state
    public func togglePlugin(_ id: String) async throws {
        guard descriptors[id] != nil || plugins[id] != nil else {
            throw PluginError.notFound(id)
        }

        if isPluginEnabled(id: id) {
            await disablePlugin(id)
        } else {
            try await enablePlugin(id)
        }
    }

    /// Activate all enabled plugins (call on app launch)
    public func activateEnabledPlugins() async {
        for id in pluginOrder where plugins[id] != nil && isPluginEnabled(id: id) {

            do {
                try await enablePlugin(id)
            } catch {
                print("Failed to activate plugin \(id): \(error)")
            }
        }
    }

    /// Deactivate all plugins (call on app termination)
    public func deactivateAllPlugins() async {
        for id in pluginOrder {
            await disablePlugin(id)
        }
    }

    // MARK: - Positioned Plugins

    /// Get plugins at a specific closed notch position
    public func plugins(at position: ClosedNotchPosition) -> [AnyNotchPlugin] {
        activePlugins.filter { plugin in
            guard let pluginPosition = plugin.closedNotchPosition else { return false }
            return pluginPosition == position
        }
    }

    // MARK: - Plugin Ordering

    /// Reorder plugins (for tab bar, settings, etc.)
    public func reorderPlugins(_ order: [String]) {
        // Validate all IDs exist
        let validOrder = order.filter { hasPlugin(id: $0) }
        let missing = Set(pluginOrder).subtracting(Set(validOrder))

        // New order + any missing plugins at the end
        pluginOrder = validOrder + Array(missing)
    }

    /// Move a plugin to a new position
    public func movePlugin(_ id: String, to index: Int) {
        guard let currentIndex = pluginOrder.firstIndex(of: id) else { return }
        pluginOrder.remove(at: currentIndex)
        pluginOrder.insert(id, at: min(index, pluginOrder.count))
    }

    // MARK: - Display Arbitration

    /// Get the plugin ID that has the highest priority request to be displayed
    public func highestPriorityClosedNotchPlugin() -> String? {
        DisplayPrioritizer.highestPriority(among: activePlugins)
    }

}
