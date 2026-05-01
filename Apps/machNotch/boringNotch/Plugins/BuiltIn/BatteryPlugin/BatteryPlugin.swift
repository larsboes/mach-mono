//
//  BatteryPlugin.swift
//  boringNotch
//
//  Built-in battery plugin.
//  Displays battery status in the notch.
//

import SwiftUI

@MainActor
@Observable
final class BatteryPlugin: NotchPlugin, PositionedPlugin {
    
    // MARK: - NotchPlugin
    
    let id = PluginID.battery
    
    let metadata = PluginMetadata(
        name: "Battery",
        description: "Monitor battery status and get notifications",
        icon: "battery.100",
        version: "1.0.0",
        author: "boringNotch",
        category: .system
    )
    
    var isEnabled: Bool = true
    
    private(set) var state: PluginState = .inactive
    
    // MARK: - PositionedPlugin
    
    var closedNotchPosition: ClosedNotchPosition { .farRight }
    
    // MARK: - Dependencies
    
    var batteryService: (any BatteryServiceProtocol)?
    private var settings: PluginSettings?
    
    // MARK: - Lifecycle
    
    func activate(context: PluginContext) async throws {
        state = .activating
        
        self.batteryService = context.services.battery
        self.settings = context.settings
        
        state = .active
    }
    
    func deactivate() async {
        batteryService = nil
        settings = nil
        state = .inactive
    }
    
    // MARK: - UI Slots

    var displayRequest: DisplayRequest? {
        guard isEnabled, state.isActive, let service = batteryService else { return nil }

        // Check for low/high battery levels
        let level = Int(service.levelBattery)
        let lowThreshold = settings?.get("lowBatteryThreshold", default: 20) ?? 20
        let highThreshold = settings?.get("highBatteryThreshold", default: 80) ?? 80
        
        // Critical: Low Battery
        if !service.isCharging && level <= lowThreshold {
            return DisplayRequest(priority: .critical, category: DisplayRequest.system)
        }
        
        // High: High Battery (only when charging)
        if service.isCharging && level >= highThreshold {
            return DisplayRequest(priority: .normal, category: DisplayRequest.system)
        }
        
        return nil
    }

    @ViewBuilder
    func closedNotchContent() -> some View {
        if isEnabled, state.isActive, let service = batteryService {
            PluginBatteryView(service: service)
        }
    }

    @ViewBuilder
    func menuBarView() -> some View {
        if isEnabled, state.isActive, let service = batteryService {
            Text("Battery: \(Int(service.levelBattery))%\(service.isCharging ? " ⚡" : "")")
        }
    }
    
    @ViewBuilder
    func settingsContent() -> some View {
        // Reuse existing Charge view (BatterySettingsView)
        Charge()
    }
}

// MARK: - View Wrappers

struct PluginBatteryView: View {
    let service: any BatteryServiceProtocol
    @Environment(BoringViewModel.self) var vm
    
    var body: some View {
        HStack(spacing: 0) {
            HStack {
                Text(service.statusText)
                    .font(.subheadline)
                    .foregroundStyle(Color.white)
            }

            Rectangle()
                .fill(Color.black)
                .frame(width: vm.closedNotchSize.width + 10)

            HStack {
                BoringBatteryView(
                    batteryWidth: 30,
                    isCharging: service.isCharging,
                    isInLowPowerMode: service.isInLowPowerMode,
                    isPluggedIn: service.isPluggedIn,
                    levelBattery: service.levelBattery,
                    maxCapacity: service.maxCapacity,
                    timeToFullCharge: service.timeToFullCharge,
                    isForNotification: true
                )
            }
            .frame(width: 76, alignment: .trailing)
        }
    }
}
