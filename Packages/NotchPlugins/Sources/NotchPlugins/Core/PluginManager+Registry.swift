//
//  PluginManager+Registry.swift
//  NotchPlugins
//
//  Lazy descriptor registration and instance lookup.
//

import Foundation

@MainActor
extension PluginManager {
    /// Register a lazy plugin descriptor with the manager.
    public func registerDescriptor(_ descriptor: PluginDescriptor) {
        descriptors[descriptor.id] = descriptor
        pluginEnabledState[descriptor.id] = pluginEnabledState[descriptor.id] ?? true
        if !pluginOrder.contains(descriptor.id) {
            pluginOrder.append(descriptor.id)
        }
    }

    /// Register an already-instantiated plugin with the manager.
    public func registerPlugin(_ plugin: any NotchPlugin) {
        let wrapped = AnyNotchPlugin(plugin)
        plugins[plugin.id] = wrapped
        pluginEnabledState[plugin.id] = plugin.isEnabled
        descriptors[plugin.id] = PluginDescriptor(
            id: plugin.id,
            metadata: plugin.metadata,
            capabilities: capabilities(for: wrapped),
            closedNotchPosition: wrapped.closedNotchPosition,
            supportedExportFormats: exportFormats(for: wrapped),
            factory: { plugin }
        )
        if !pluginOrder.contains(plugin.id) {
            pluginOrder.append(plugin.id)
        }
    }

    /// Unregister a plugin.
    public func unregisterPlugin(id: String) async {
        guard descriptors[id] != nil || plugins[id] != nil else { return }

        if let plugin = plugins[id], plugin.state.isActive {
            await plugin.deactivate()
        }

        descriptors.removeValue(forKey: id)
        plugins.removeValue(forKey: id)
        pluginEnabledState.removeValue(forKey: id)
        pluginOrder.removeAll { $0 == id }
    }

    /// Get a plugin by ID, constructing it on first access.
    public func plugin(id: String) -> AnyNotchPlugin? {
        try? instantiatePlugin(id: id)
    }

    /// Get a plugin by ID with a specific type, constructing it on first access.
    public func plugin<T: NotchPlugin>(id: String, as type: T.Type) -> T? {
        plugin(id: id)?.underlying as? T
    }

    /// Check if a plugin is registered without constructing it.
    public func hasPlugin(id: String) -> Bool {
        descriptors[id] != nil || plugins[id] != nil
    }

    /// Check if a plugin is enabled without constructing it.
    public func isPluginEnabled(id: String) -> Bool {
        if let plugin = plugins[id] {
            return plugin.isEnabled
        }
        return pluginEnabledState[id] ?? false
    }

    /// Get metadata and lifecycle state without forcing construction.
    public func summary(id: String) -> PluginSummary? {
        if let plugin = plugins[id] {
            return PluginSummary(
                id: plugin.id,
                metadata: plugin.metadata,
                origin: descriptors[plugin.id]?.origin ?? .builtIn,
                capabilities: capabilities(for: plugin),
                closedNotchPosition: plugin.closedNotchPosition,
                supportedExportFormats: exportFormats(for: plugin),
                isEnabled: plugin.isEnabled,
                state: plugin.state
            )
        }

        guard let descriptor = descriptors[id] else { return nil }
        return PluginSummary(
            id: descriptor.id,
            metadata: descriptor.metadata,
            origin: descriptor.origin,
            capabilities: descriptor.capabilities,
            closedNotchPosition: descriptor.closedNotchPosition,
            supportedExportFormats: descriptor.supportedExportFormats,
            isEnabled: pluginEnabledState[id] ?? true,
            state: .inactive
        )
    }

    func instantiatePlugin(id: String) throws -> AnyNotchPlugin {
        if let plugin = plugins[id] {
            return plugin
        }

        guard let descriptor = descriptors[id] else {
            throw PluginError.notFound(id)
        }

        let plugin = descriptor.makePlugin()
        plugin.isEnabled = pluginEnabledState[id] ?? true
        let wrapped = AnyNotchPlugin(plugin)
        plugins[id] = wrapped
        return wrapped
    }

    private func capabilities(for plugin: AnyNotchPlugin) -> PluginCapabilities {
        var capabilities: PluginCapabilities = []
        if plugin.hasClosedNotchContent { capabilities.insert(.closedNotchContent) }
        if plugin.hasExpandedPanelContent { capabilities.insert(.expandedPanelContent) }
        if plugin.hasSettingsContent { capabilities.insert(.settingsContent) }
        if plugin.hasMenuBarContent { capabilities.insert(.menuBarContent) }
        if plugin.underlying is any ExportablePlugin { capabilities.insert(.exportable) }
        if plugin.closedNotchPosition != nil { capabilities.insert(.positioned) }
        return capabilities
    }

    private func exportFormats(for plugin: AnyNotchPlugin) -> [ExportFormat] {
        guard let exportable = plugin.underlying as? any ExportablePlugin else { return [] }
        return exportable.supportedExportFormats
    }
}
