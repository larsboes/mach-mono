//
//  PluginManager+ViewHelpers.swift
//  machNotch
//
//  Extracted view helpers and export support from PluginManager.
//

import SwiftUI

// MARK: - View Helpers

extension PluginManager {
    /// Plugins that show content in the expanded panel
    var panelPlugins: [AnyNotchPlugin] {
        activePlugins.filter { $0.hasExpandedPanelContent }
    }

    /// Get the view for a plugin's closed notch content
    @ViewBuilder
    public func closedNotchView(for id: String) -> some View {
        let _ = pluginActivationGeneration
        if let wrapper = plugin(id: id), wrapper.state.isActive, wrapper.hasClosedNotchContent {
            wrapper.closedNotchContent()
        } else {
            activationPlaceholder(for: id)
        }
    }

    /// Get the view for a plugin's expanded panel content
    @ViewBuilder
    public func expandedPanelView(for id: String) -> some View {
        let _ = pluginActivationGeneration
        if let wrapper = plugin(id: id), wrapper.state.isActive, wrapper.hasExpandedPanelContent {
            wrapper.expandedPanelContent()
        } else {
            activationPlaceholder(for: id)
        }
    }

    /// Get the menu bar contribution for a plugin
    @ViewBuilder
    public func menuBarView(for id: String) -> some View {
        let _ = pluginActivationGeneration
        if let wrapper = plugin(id: id), wrapper.state.isActive, wrapper.hasMenuBarContent {
            wrapper.menuBarView()
        } else {
            activationPlaceholder(for: id)
        }
    }

    /// Get the view for a plugin's settings content
    @ViewBuilder
    public func settingsView(for id: String) -> some View {
        let _ = pluginActivationGeneration
        if let wrapper = plugin(id: id), wrapper.hasSettingsContent {
            wrapper.settingsContent()
                .task(id: id) {
                    try? await self.enablePlugin(id)
                }
        } else {
            activationPlaceholder(for: id)
        }
    }

    private func activationPlaceholder(for id: String) -> some View {
        Color.clear
            .frame(minWidth: 1, minHeight: 1)
            .task(id: id) {
                guard self.isPluginEnabled(id: id) else { return }
                try? await self.enablePlugin(id)
            }
    }
}

// MARK: - Export Support

extension PluginManager {
    /// Get all exportable plugins
    public var exportablePlugins: [AnyNotchPlugin] {
        return activePlugins
    }

    /// Export data from a specific plugin
    public func exportPluginData(id: String, format: ExportFormat) async throws -> Data {
        guard let plugin = plugin(id: id) else { throw PluginError.notFound(id) }
        guard plugin.state.isActive else { throw PluginError.invalidState("Plugin not active") }
        guard let exportable = plugin.underlying as? any ExportablePlugin else {
            throw PluginError.exportFailed("Export not supported for plugin '\(id)'")
        }
        guard exportable.supportedExportFormats.contains(format) else {
            throw PluginError.exportFailed("Format '\(format.rawValue)' not supported by plugin '\(id)'")
        }
        return try await exportable.exportData(format: format)
    }

    /// Export data from all exportable plugins
    public func exportAllPluginData(format: ExportFormat) async throws -> [String: Data] {
        var results: [String: Data] = [:]

        for plugin in exportablePlugins {
            do {
                let data = try await exportPluginData(id: plugin.id, format: format)
                results[plugin.id] = data
            } catch {
                print("Failed to export \(plugin.id): \(error)")
            }
        }

        return results
    }
}

// MARK: - Environment Key

private struct PluginManagerKey: EnvironmentKey {
    static let defaultValue: PluginManager? = nil
}

extension EnvironmentValues {
    public var pluginManager: PluginManager? {
        get { self[PluginManagerKey.self] }
        set { self[PluginManagerKey.self] = newValue }
    }
}

// MARK: - Preview Support

#if DEBUG
    extension PluginManager {
        /// Create a preview manager with mock services
        static func preview() -> PluginManager {
            fatalError("Preview not implemented - needs mock services")
        }
    }
#endif
