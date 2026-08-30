//
//  PluginSummary.swift
//  NotchPlugins
//
//  Descriptor-backed plugin state for metadata-only UI and API surfaces.
//

import Foundation

public struct PluginSummary: Identifiable, Sendable {
    public let id: String
    public let metadata: PluginMetadata
    public let origin: PluginDescriptorOrigin
    public let capabilities: PluginCapabilities
    public let closedNotchPosition: ClosedNotchPosition?
    public let supportedExportFormats: [ExportFormat]
    public let isEnabled: Bool
    public let state: PluginState
    /// Declaration plus detection result, or nil when nothing overlaps this plugin.
    public let coexistence: ResolvedCoexistence?

    public var isActive: Bool {
        state.isActive
    }

    public var isExternal: Bool {
        if case .external = origin {
            return true
        }
        return false
    }

    public var hasClosedNotchContent: Bool {
        capabilities.contains(.closedNotchContent)
    }

    public var hasExpandedPanelContent: Bool {
        capabilities.contains(.expandedPanelContent)
    }

    public var hasSettingsContent: Bool {
        capabilities.contains(.settingsContent)
    }

    public var hasMenuBarContent: Bool {
        capabilities.contains(.menuBarContent)
    }

    public var isExportable: Bool {
        capabilities.contains(.exportable)
    }

    /// True when an overlapping app is installed, so this plugin duplicates it.
    public var isRedundant: Bool {
        coexistence?.isRedundant ?? false
    }
}
