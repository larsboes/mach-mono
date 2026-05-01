//
//  PluginContext.swift
//  boringNotch
//
//  Dependency injection context provided to plugins during activation.
//  Uses existing types from the codebase - does NOT redefine them.
//

import Foundation

// MARK: - Plugin Context

/// Injected into plugins during activation.
/// Provides access to services, settings, and inter-plugin communication.
@MainActor
final class PluginContext {
    /// Plugin-specific settings (namespaced in Defaults)
    let settings: PluginSettings

    /// Access to shared services
    let services: any NotchServiceProvider

    /// For inter-plugin communication
    let eventBus: PluginEventBus

    /// App-wide state
    let appState: AppStateProviding

    /// App-wide media settings (visualizer, music live activity, etc.)
    let mediaSettings: any MediaSettings

    init(
        settings: PluginSettings,
        services: any NotchServiceProvider,
        eventBus: PluginEventBus,
        appState: AppStateProviding,
        mediaSettings: any MediaSettings
    ) {
        self.settings = settings
        self.services = services
        self.eventBus = eventBus
        self.appState = appState
        self.mediaSettings = mediaSettings
    }
}

// MARK: - App State Protocol

/// Provides access to app-wide state

/// Note: Kept minimal for MVP - expand as features migrate to plugin system

@MainActor

protocol AppStateProviding: AnyObject {

    /// Whether the screen is currently locked

    var isScreenLocked: Bool { get }

}

// MARK: - Service Protocols

// Note: Service protocols are defined in Plugins/Services/

// MARK: - Environment Keys
