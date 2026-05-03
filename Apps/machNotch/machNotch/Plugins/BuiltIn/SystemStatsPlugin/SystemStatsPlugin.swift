//
//  SystemStatsPlugin.swift
//  machNotch
//

import SwiftUI
import NotchCore

public final class SystemStatsPlugin: NotchPlugin {
    public let id = PluginID.systemStats
    public let name = "System Stats"
    public let capability: PluginCapabilities = [.standard]
    
    public var state = PluginState()
    
    public init() {}
    
    public func activate(context: PluginContext) async {
        state.isActive = true
    }
    
    public func deactivate() {
        state.isActive = false
    }
    
    @ViewBuilder
    public func closedNotchContent() -> some View {
        Text("Stats") // Placeholder
    }
    
    @ViewBuilder
    public func expandedPanelContent() -> some View {
        Text("System Stats Panel") // Placeholder
    }
    
    @ViewBuilder
    public func settingsContent() -> some View {
        Text("System Stats Settings") // Placeholder
    }
}
