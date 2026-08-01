//
//  SystemStatsPlugin.swift
//  machNotch
//
//  Created by Lars Boes
//

import SwiftUI

@MainActor
@Observable
public final class SystemStatsPlugin: NotchPlugin, PositionedPlugin {
    public let id = PluginID.systemStats

    public let metadata = PluginMetadata(
        name: "System Stats",
        description: "Monitor CPU, memory, disk, and network activity",
        icon: "gauge.with.dots.needle.50percent",
        version: "1.0.0",
        author: "machNotch",
        category: .system
    )

    public var isEnabled: Bool = true
    public private(set) var state: PluginState = .inactive
    public var closedNotchPosition: ClosedNotchPosition { .farRight }

    private var settings: PluginSettings?
    public var statsService: (any SystemStatsServiceProtocol)?

    public init() {}

    public func activate(context: PluginContext) async throws {
        state = .activating
        settings = context.settings
        isEnabled = context.settings.isEnabled
        statsService = context.systemServices.systemStats
        statsService?.refreshInterval = refreshInterval
        statsService?.startMonitoring()
        state = .active
    }

    public func deactivate() async {
        statsService?.stopMonitoring()
        statsService = nil
        settings = nil
        state = .inactive
    }

    public var displayRequest: DisplayRequest? {
        guard isEnabled, state.isActive, settings?.showInClosedNotch ?? true else { return nil }
        return DisplayRequest(priority: .background, category: DisplayRequest.system)
    }

    @ViewBuilder
    public func closedNotchContent() -> some View {
        if isEnabled, state.isActive, settings?.showInClosedNotch ?? true, let statsService {
            SystemStatsClosedView(stats: statsService.stats, configuration: configuration)
        }
    }

    @ViewBuilder
    public func expandedPanelContent() -> some View {
        if isEnabled, state.isActive, let statsService {
            SystemStatsExpandedView(
                stats: statsService.stats,
                history: statsService.history,
                configuration: configuration
            )
        }
    }

    @ViewBuilder
    public func settingsContent() -> some View {
        SystemStatsSettingsView(plugin: self)
    }

    public var configuration: SystemStatsConfiguration {
        SystemStatsConfiguration(
            showCPU: showCPU,
            showRAM: showRAM,
            showDisk: showDisk,
            showNetwork: showNetwork
        )
    }

    public var showCPU: Bool {
        get { settings?.get("showCPU", default: true) ?? true }
        set { settings?.set("showCPU", value: newValue) }
    }

    public var showRAM: Bool {
        get { settings?.get("showRAM", default: true) ?? true }
        set { settings?.set("showRAM", value: newValue) }
    }

    public var showDisk: Bool {
        get { settings?.get("showDisk", default: true) ?? true }
        set { settings?.set("showDisk", value: newValue) }
    }

    public var showNetwork: Bool {
        get { settings?.get("showNetwork", default: true) ?? true }
        set { settings?.set("showNetwork", value: newValue) }
    }

    public var refreshInterval: Double {
        get { settings?.get("refreshInterval", default: 3.0) ?? 3.0 }
        set {
            let clamped = min(max(newValue, 1), 5)
            settings?.set("refreshInterval", value: clamped)
            statsService?.refreshInterval = clamped
        }
    }
}
