//
//  SystemStatsPlugin.swift
//  machNotch
//

import SwiftUI

@MainActor
@Observable
final class SystemStatsPlugin: NotchPlugin, PositionedPlugin {
    let id = PluginID.systemStats

    let metadata = PluginMetadata(
        name: "System Stats",
        description: "Monitor CPU, memory, disk, and network activity",
        icon: "gauge.with.dots.needle.50percent",
        version: "1.0.0",
        author: "machNotch",
        category: .system
    )

    var isEnabled: Bool = true
    private(set) var state: PluginState = .inactive
    var closedNotchPosition: ClosedNotchPosition { .farRight }

    private var settings: PluginSettings?
    var statsService: (any SystemStatsServiceProtocol)?

    init() {}

    func activate(context: PluginContext) async throws {
        state = .activating
        settings = context.settings
        isEnabled = context.settings.isEnabled
        statsService = context.systemServices.systemStats
        statsService?.refreshInterval = refreshInterval
        statsService?.startMonitoring()
        state = .active
    }

    func deactivate() async {
        statsService?.stopMonitoring()
        statsService = nil
        settings = nil
        state = .inactive
    }

    var displayRequest: DisplayRequest? {
        guard isEnabled, state.isActive, settings?.showInClosedNotch ?? true else { return nil }
        return DisplayRequest(priority: .background, category: DisplayRequest.system)
    }

    @ViewBuilder
    func closedNotchContent() -> some View {
        if isEnabled, state.isActive, settings?.showInClosedNotch ?? true, let statsService {
            SystemStatsClosedView(stats: statsService.stats, configuration: configuration)
        }
    }

    @ViewBuilder
    func expandedPanelContent() -> some View {
        if isEnabled, state.isActive, let statsService {
            SystemStatsExpandedView(
                stats: statsService.stats,
                history: statsService.history,
                configuration: configuration
            )
        }
    }

    @ViewBuilder
    func settingsContent() -> some View {
        SystemStatsSettingsView(plugin: self)
    }

    var configuration: SystemStatsConfiguration {
        SystemStatsConfiguration(
            showCPU: showCPU,
            showRAM: showRAM,
            showDisk: showDisk,
            showNetwork: showNetwork
        )
    }

    var showCPU: Bool {
        get { settings?.get("showCPU", default: true) ?? true }
        set { settings?.set("showCPU", value: newValue) }
    }

    var showRAM: Bool {
        get { settings?.get("showRAM", default: true) ?? true }
        set { settings?.set("showRAM", value: newValue) }
    }

    var showDisk: Bool {
        get { settings?.get("showDisk", default: true) ?? true }
        set { settings?.set("showDisk", value: newValue) }
    }

    var showNetwork: Bool {
        get { settings?.get("showNetwork", default: true) ?? true }
        set { settings?.set("showNetwork", value: newValue) }
    }

    var refreshInterval: Double {
        get { settings?.get("refreshInterval", default: 3.0) ?? 3.0 }
        set {
            let clamped = min(max(newValue, 1), 5)
            settings?.set("refreshInterval", value: clamped)
            statsService?.refreshInterval = clamped
        }
    }
}
