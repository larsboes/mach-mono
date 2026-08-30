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
    /// Set when a third-party app already covers this plugin's job.
    /// Metadata only, so settings can show the overlap without building the plugin.
    public let coexistence: PluginCoexistence?
    private let factory: @MainActor () -> any NotchPlugin

    public init(
        id: String,
        metadata: PluginMetadata,
        origin: PluginDescriptorOrigin = .builtIn,
        capabilities: PluginCapabilities = [],
        closedNotchPosition: ClosedNotchPosition? = nil,
        supportedExportFormats: [ExportFormat] = [],
        coexistence: PluginCoexistence? = nil,
        factory: @escaping @MainActor () -> any NotchPlugin
    ) {
        self.id = id
        self.metadata = metadata
        self.origin = origin
        self.capabilities = capabilities
        self.closedNotchPosition = closedNotchPosition
        self.supportedExportFormats = supportedExportFormats
        self.coexistence = coexistence
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

    // MARK: - Service capabilities

    // An external plugin receives only the service groups it declares here.
    // Built-in plugins receive every group; they ship with the app and are not
    // the threat this guards against.

    public static let mediaServices = PluginCapabilities(rawValue: 1 << 6)
    public static let systemServices = PluginCapabilities(rawValue: 1 << 7)
    public static let storageServices = PluginCapabilities(rawValue: 1 << 8)
    public static let uiServices = PluginCapabilities(rawValue: 1 << 9)
    public static let extensionServices = PluginCapabilities(rawValue: 1 << 10)

    /// Every service group. The grant a built-in plugin receives.
    public static let allServices: PluginCapabilities = [
        .mediaServices, .systemServices, .storageServices, .uiServices, .extensionServices,
    ]
}
