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
}
