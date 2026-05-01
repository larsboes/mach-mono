//
//  PluginManager+ViewHelpers.swift
//  boringNotch
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
    func closedNotchView(for id: String) -> some View {
        if let wrapper = plugin(id: id), wrapper.state.isActive, wrapper.hasClosedNotchContent {
            wrapper.closedNotchContent()
        }
    }

    /// Get the view for a plugin's expanded panel content
    @ViewBuilder
    func expandedPanelView(for id: String) -> some View {
        if let wrapper = plugin(id: id), wrapper.state.isActive, wrapper.hasExpandedPanelContent {
            wrapper.expandedPanelContent()
        }
    }

    /// Get the menu bar contribution for a plugin
    @ViewBuilder
    func menuBarView(for id: String) -> some View {
        if let wrapper = plugin(id: id), wrapper.state.isActive, wrapper.hasMenuBarContent {
            wrapper.menuBarView()
        }
    }

    /// Get the view for a plugin's settings content
    @ViewBuilder
    func settingsView(for id: String) -> some View {
        if let wrapper = plugin(id: id), wrapper.hasSettingsContent {
            wrapper.settingsContent()
        }
    }
}

// MARK: - Export Support

extension PluginManager {
    /// Get all exportable plugins
    var exportablePlugins: [AnyNotchPlugin] {
        return activePlugins
    }

    /// Export data from a specific plugin
    func exportPluginData(id: String, format: ExportFormat) async throws -> Data {
        guard let plugin = plugin(id: id) else {
            throw PluginError.notFound(id)
        }

        guard plugin.state.isActive else {
            throw PluginError.invalidState("Plugin not active")
        }

        throw PluginError.exportFailed("Export not implemented for this plugin")
    }

    /// Export data from all exportable plugins
    func exportAllPluginData(format: ExportFormat) async throws -> [String: Data] {
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
    var pluginManager: PluginManager? {
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
