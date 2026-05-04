//
//  BatteryPlugin.swift
//  machNotch
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
        author: "machNotch",
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

        batteryService = context.systemServices.battery
        settings = context.settings
        isEnabled = context.settings.isEnabled

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

        switch service.alertKind(initial: true) {
        case .lowBattery:
            return DisplayRequest(priority: .critical, category: DisplayRequest.system)
        case .highBattery:
            return DisplayRequest(priority: .normal, category: DisplayRequest.system)
        case nil:
            return nil
        }
    }

    @ViewBuilder
    func closedNotchContent() -> some View {
        if isEnabled, state.isActive, let service = batteryService {
            PluginBatteryClosedView(snapshot: service.snapshot)
        }
    }

    @ViewBuilder
    func expandedPanelContent() -> some View {
        if isEnabled, state.isActive, let service = batteryService {
            BatteryExpandedPanelView(snapshot: service.snapshot)
        }
    }

    @ViewBuilder
    func menuBarView() -> some View {
        if isEnabled, state.isActive, let service = batteryService {
            BatteryMenuBarSummary(snapshot: service.snapshot)
        }
    }

    @ViewBuilder
    func settingsContent() -> some View {
        Charge()
    }

    @ViewBuilder
    func headerContent() -> some View {
        if isEnabled, state.isActive, let service = batteryService {
            BatteryStatusView(snapshot: service.snapshot, isForNotification: false)
        }
    }
}

// MARK: - View Wrappers

private struct PluginBatteryClosedView: View {
    let snapshot: BatterySnapshot
    @Environment(NotchViewModel.self) var vm

    var body: some View {
        HStack(spacing: 0) {
            HStack {
                Text(snapshot.statusText)
                    .font(.subheadline)
                    .foregroundStyle(Color.white)
            }

            Rectangle()
                .fill(Color.black)
                .frame(width: vm.closedNotchSize.width + 10)

            HStack {
                BatteryStatusView(snapshot: snapshot, isForNotification: true)
            }
            .frame(width: 76, alignment: .trailing)
        }
    }
}

private struct BatteryExpandedPanelView: View {
    let snapshot: BatterySnapshot

    var body: some View {
        VStack(spacing: 14) {
            Label("Battery", systemImage: "battery.100")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            BatteryMenuView(
                isPluggedIn: snapshot.isPluggedIn,
                isCharging: snapshot.isCharging,
                levelBattery: Float(snapshot.level),
                maxCapacity: Float(snapshot.maxCapacity),
                timeToFullCharge: snapshot.timeToFullCharge,
                isInLowPowerMode: snapshot.isInLowPowerMode,
                onDismiss: {}
            )
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct BatteryMenuBarSummary: View {
    let snapshot: BatterySnapshot

    var body: some View {
        Label {
            Text("Battery: \(snapshot.level)%\(snapshot.isCharging ? " charging" : "")")
        } icon: {
            Image(systemName: snapshot.isCharging ? "battery.100.bolt" : "battery.100")
        }
    }
}
