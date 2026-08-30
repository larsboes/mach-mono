//
//  PluginContext.swift
//  machNotch
//
//  Dependency injection context provided to plugins during activation.
//  Uses existing types from the codebase - does NOT redefine them.
//

import Foundation

// MARK: - Plugin Context

/// Injected into plugins during activation.
/// Provides access to services, settings, and inter-plugin communication.
@MainActor
public final class PluginContext {
    /// Plugin-specific settings (namespaced in Defaults)
    public let settings: PluginSettings

    /// The full container. Deliberately private: a plugin reaches services only
    /// through the narrowed accessors below, and only for groups it declared.
    private let provider: any NotchServiceProvider

    /// Service groups this plugin was granted. Built-in plugins get `.allServices`.
    public let grantedCapabilities: PluginCapabilities

    /// For inter-plugin communication
    public let eventBus: PluginEventBus

    /// App-wide state
    public let appState: AppStateProviding

    /// App-wide media settings (visualizer, music live activity, etc.)
    public let mediaSettings: any MediaSettings

    public init(
        settings: PluginSettings,
        services: any NotchServiceProvider,
        eventBus: PluginEventBus,
        appState: AppStateProviding,
        mediaSettings: any MediaSettings,
        grantedCapabilities: PluginCapabilities = .allServices
    ) {
        self.settings = settings
        self.provider = services
        self.eventBus = eventBus
        self.appState = appState
        self.mediaSettings = mediaSettings
        self.grantedCapabilities = grantedCapabilities
    }

    // MARK: - Narrowed Service Accessors
    //
    // Each accessor returns a facade that conforms to one sub-protocol only, so a
    // plugin cannot cast it back up to NotchServiceProvider. Returning the container
    // directly would make the narrowing advisory, because ServiceContainer conforms
    // to every sub-protocol.
    //
    // Reaching for a group the plugin did not declare is a programming error and
    // traps on first access, which happens at activation.

    /// Music, lyrics, sound — for media-centric plugins.
    public var mediaServices: any MediaServiceProvider {
        MediaServiceFacade(granted(.mediaServices, "mediaServices"))
    }

    /// Volume, brightness, battery, keyboard backlight, system stats.
    public var systemServices: any SystemServiceProvider {
        SystemServiceFacade(granted(.systemServices, "systemServices"))
    }

    /// Shelf, temporary files, image processing, thumbnails, QuickLook.
    public var storageServices: any StorageServiceProvider {
        StorageServiceFacade(granted(.storageServices, "storageServices"))
    }

    /// Notifications, system notification observer, sharing, drag-drop, webcam, face.
    public var uiServices: any UIServiceProvider {
        UIServiceFacade(granted(.uiServices, "uiServices"))
    }

    /// AI, bluetooth, clipboard, calendar, weather, API route registrar.
    public var pluginExtensionServices: any PluginExtensionServiceProvider {
        PluginExtensionServiceFacade(granted(.extensionServices, "extensionServices"))
    }

    private func granted(
        _ capability: PluginCapabilities,
        _ name: String
    ) -> any NotchServiceProvider {
        precondition(
            grantedCapabilities.contains(capability),
            "Plugin used \(name) without declaring it. Add .\(name) to the "
                + "capabilities of its PluginDescriptor."
        )
        return provider
    }
}

// MARK: - App State Protocol

/// Provides access to app-wide state

/// Note: Kept minimal for MVP - expand as features migrate to plugin system

@MainActor
public protocol AppStateProviding: AnyObject {
    /// Whether the screen is currently locked
    var isScreenLocked: Bool { get }
}

// MARK: - Service Protocols

// Note: Service protocols are defined in Plugins/Services/

// MARK: - Environment Keys
