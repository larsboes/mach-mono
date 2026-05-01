//
//  PluginManager.swift
//  boringNotch
//
//  Central registry and lifecycle manager for all plugins.
//

import Foundation
import Combine

// MARK: - Plugin Manager

/// Central registry for all plugins.
/// Manages plugin lifecycle, provides access to plugins for views,
/// and handles inter-plugin communication.
@MainActor
@Observable
final class PluginManager {
    // MARK: - Properties

    /// All registered plugins (enabled and disabled)
    private var plugins: [String: AnyNotchPlugin] = [:]

    /// Plugin activation order
    private var pluginOrder: [String] = []

    /// Service container for dependency injection
    let services: ServiceContainer

    /// Incremented each time a plugin activates or deactivates.
    /// ContentView observes this to re-evaluate the state machine after plugin lifecycle changes.
    private(set) var pluginActivationGeneration: Int = 0

    /// Event bus for inter-plugin communication
    let eventBus: PluginEventBus

    /// App state provider
    private let appState: AppStateProviding

    /// Cancellables for subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    /// All registered plugin IDs
    var allPluginIds: [String] {
        pluginOrder
    }

    /// All registered plugins (ordered)
    var allPlugins: [AnyNotchPlugin] {
        pluginOrder.compactMap { plugins[$0] }
    }

    /// All active (enabled and activated) plugins
    var activePlugins: [AnyNotchPlugin] {
        pluginOrder
            .compactMap { plugins[$0] }
            .filter { $0.isEnabled && $0.state.isActive }
    }

    /// All enabled plugins (may still be activating)
    var enabledPlugins: [AnyNotchPlugin] {
        pluginOrder
            .compactMap { plugins[$0] }
            .filter { $0.isEnabled }
    }

    // MARK: - Initialization

    /// App-wide media settings, forwarded to plugin contexts
    private let mediaSettings: any MediaSettings

    init(
        services: ServiceContainer,
        eventBus: PluginEventBus,
        appState: AppStateProviding,
        mediaSettings: any MediaSettings,
        coordinator: any NotchAnimationStateProviding,
        builtInPlugins: [any NotchPlugin] = []
    ) {
        self.services = services
        self.eventBus = eventBus
        self.appState = appState
        self.mediaSettings = mediaSettings

        // Inject shelf service into coordinator
        coordinator.shelfService = services.shelf

        // Register built-in plugins
        for plugin in builtInPlugins {
            registerPlugin(plugin)
        }
    }

    // MARK: - Plugin Registration

    /// Register a plugin with the manager
    func registerPlugin(_ plugin: any NotchPlugin) {
        let wrapped = AnyNotchPlugin(plugin)
        plugins[plugin.id] = wrapped
        pluginOrder.append(plugin.id)
    }

    /// Unregister a plugin
    func unregisterPlugin(id: String) async {
        guard let plugin = plugins[id] else { return }

        // Deactivate if active
        if plugin.state.isActive {
            await plugin.deactivate()
        }

        plugins.removeValue(forKey: id)
        pluginOrder.removeAll { $0 == id }
    }

    // MARK: - Plugin Lifecycle

    /// Enable and activate a plugin
    func enablePlugin(_ id: String) async throws {
        guard let plugin = plugins[id] else {
            throw PluginError.notFound(id)
        }

        guard !plugin.state.isActive else { return }

        let context = PluginContext(
            settings: PluginSettings(pluginId: id),
            services: services,
            eventBus: eventBus,
            appState: appState,
            mediaSettings: mediaSettings
        )

        do {
            try await plugin.activate(context: context)
            plugin.isEnabled = true
            pluginActivationGeneration += 1
            eventBus.emit(.pluginActivated, from: id)
        } catch {
            throw PluginError.activationFailed(error.localizedDescription)
        }
    }

    /// Disable and deactivate a plugin
    func disablePlugin(_ id: String) async {
        guard let plugin = plugins[id] else { return }

        await plugin.deactivate()
        plugin.isEnabled = false
        eventBus.emit(.pluginDeactivated, from: id)
    }

    /// Toggle plugin enabled state
    func togglePlugin(_ id: String) async throws {
        guard let plugin = plugins[id] else {
            throw PluginError.notFound(id)
        }

        if plugin.isEnabled {
            await disablePlugin(id)
        } else {
            try await enablePlugin(id)
        }
    }

    /// Activate all enabled plugins (call on app launch)
    func activateEnabledPlugins() async {
        for id in pluginOrder {
            guard let plugin = plugins[id], plugin.isEnabled else { continue }

            do {
                try await enablePlugin(id)
            } catch {
                print("Failed to activate plugin \(id): \(error)")
            }
        }
    }

    /// Deactivate all plugins (call on app termination)
    func deactivateAllPlugins() async {
        for id in pluginOrder {
            await disablePlugin(id)
        }
    }

    // MARK: - Plugin Access

    /// Get a plugin by ID
    func plugin(id: String) -> AnyNotchPlugin? {
        plugins[id]
    }

    /// Get a plugin by ID with specific type
    func plugin<T: NotchPlugin>(id: String, as type: T.Type) -> T? {
        plugins[id]?.underlying as? T
    }

    /// Check if a plugin is registered
    func hasPlugin(id: String) -> Bool {
        plugins[id] != nil
    }

    /// Check if a plugin is enabled
    func isPluginEnabled(id: String) -> Bool {
        plugins[id]?.isEnabled ?? false
    }

    // MARK: - Positioned Plugins

    /// Get plugins at a specific closed notch position
    func plugins(at position: ClosedNotchPosition) -> [AnyNotchPlugin] {
        activePlugins.filter { plugin in
            guard let pluginPosition = plugin.closedNotchPosition else { return false }
            return pluginPosition == position
        }
    }

    // MARK: - Plugin Ordering

    /// Reorder plugins (for tab bar, settings, etc.)
    func reorderPlugins(_ order: [String]) {
        // Validate all IDs exist
        let validOrder = order.filter { plugins[$0] != nil }
        let missing = Set(pluginOrder).subtracting(Set(validOrder))

        // New order + any missing plugins at the end
        pluginOrder = validOrder + Array(missing)
    }

    /// Move a plugin to a new position
    func movePlugin(_ id: String, to index: Int) {
        guard let currentIndex = pluginOrder.firstIndex(of: id) else { return }
        pluginOrder.remove(at: currentIndex)
        pluginOrder.insert(id, at: min(index, pluginOrder.count))
    }

    // MARK: - Display Arbitration

    /// Get the plugin ID that has the highest priority request to be displayed
    func highestPriorityClosedNotchPlugin() -> String? {
        DisplayPrioritizer.highestPriority(among: activePlugins)
    }
}
