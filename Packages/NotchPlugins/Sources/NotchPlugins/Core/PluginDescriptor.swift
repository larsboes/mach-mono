//
//  PluginDescriptor.swift
//  NotchPlugins
//
//  Metadata-first registration for lazy plugin construction.
//

import Foundation

@MainActor
public struct PluginDescriptor: Identifiable {
    public let id: String
    public let metadata: PluginMetadata
    public let origin: PluginDescriptorOrigin
    public let capabilities: PluginCapabilities
    public let closedNotchPosition: ClosedNotchPosition?
    public let supportedExportFormats: [ExportFormat]
    private let factory: @MainActor () -> any NotchPlugin

    public init(
        id: String,
        metadata: PluginMetadata,
        origin: PluginDescriptorOrigin = .builtIn,
        capabilities: PluginCapabilities = [],
        closedNotchPosition: ClosedNotchPosition? = nil,
        supportedExportFormats: [ExportFormat] = [],
        factory: @escaping @MainActor () -> any NotchPlugin
    ) {
        self.id = id
        self.metadata = metadata
        self.origin = origin
        self.capabilities = capabilities
        self.closedNotchPosition = closedNotchPosition
        self.supportedExportFormats = supportedExportFormats
        self.factory = factory
    }

    public func makePlugin() -> any NotchPlugin {
        factory()
    }
}

public enum PluginDescriptorOrigin: Hashable, Sendable {
    case builtIn
    case external(String)
}

public struct PluginCapabilities: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let closedNotchContent = PluginCapabilities(rawValue: 1 << 0)
    public static let expandedPanelContent = PluginCapabilities(rawValue: 1 << 1)
    public static let settingsContent = PluginCapabilities(rawValue: 1 << 2)
    public static let menuBarContent = PluginCapabilities(rawValue: 1 << 3)
    public static let exportable = PluginCapabilities(rawValue: 1 << 4)
    public static let positioned = PluginCapabilities(rawValue: 1 << 5)
}
