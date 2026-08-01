//
//  BatteryStatusView.swift
//  NotchPlugins
//

import SwiftUI

struct BatteryStatusView: View {

    @State var batteryWidth: CGFloat = 26
    var isCharging: Bool = false
    var isInLowPowerMode: Bool = false
    var isPluggedIn: Bool = false
    var levelBattery: Float = 0
    var maxCapacity: Float = 0
    var timeToFullCharge: Int = 0
    @State var isForNotification: Bool = false

    @State private var showPopupMenu: Bool = false
    @State private var isPressed: Bool = false
    @State private var isHoveringButton: Bool = false
    @State private var isHoveringPopover: Bool = false
    @State private var hideTask: Task<Void, Never>?

    @Environment(PluginUIContext.self) var uiContext
    @Environment(\.settings) var settings

    init(
        batteryWidth: CGFloat = 26,
        isCharging: Bool = false,
        isInLowPowerMode: Bool = false,
        isPluggedIn: Bool = false,
        levelBattery: Float = 0,
        maxCapacity: Float = 0,
        timeToFullCharge: Int = 0,
        isForNotification: Bool = false
    ) {
        self._batteryWidth = State(initialValue: batteryWidth)
        self.isCharging = isCharging
        self.isInLowPowerMode = isInLowPowerMode
        self.isPluggedIn = isPluggedIn
        self.levelBattery = levelBattery
        self.maxCapacity = maxCapacity
        self.timeToFullCharge = timeToFullCharge
        self._isForNotification = State(initialValue: isForNotification)
    }

    init(snapshot: BatterySnapshot, batteryWidth: CGFloat = 30, isForNotification: Bool) {
        self.init(
            batteryWidth: batteryWidth,
            isCharging: snapshot.isCharging,
            isInLowPowerMode: snapshot.isInLowPowerMode,
            isPluggedIn: snapshot.isPluggedIn,
            levelBattery: Float(snapshot.level),
            maxCapacity: Float(snapshot.maxCapacity),
            timeToFullCharge: snapshot.timeToFullCharge,
            isForNotification: isForNotification
        )
    }

    var body: some View {
        Button(action: {
            withAnimation { showPopupMenu.toggle() }
        }) {
            HStack {
                BatteryView(
                    levelBattery: levelBattery,
                    isPluggedIn: isPluggedIn,
                    isCharging: isCharging,
                    isInLowPowerMode: isInLowPowerMode,
                    batteryWidth: batteryWidth,
                    isForNotification: isForNotification,
                    settings: settings
                )
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .onHover { hovering in
            isHoveringButton = hovering
            if hovering {
                hideTask?.cancel()
                hideTask = nil
                withAnimation { showPopupMenu = true }
            } else {
                scheduleHideIfNeeded()
            }
        }
        .popover(isPresented: $showPopupMenu, arrowEdge: .bottom) {
            BatteryMenuView(
                isPluggedIn: isPluggedIn,
                isCharging: isCharging,
                levelBattery: levelBattery,
                maxCapacity: maxCapacity,
                timeToFullCharge: timeToFullCharge,
                isInLowPowerMode: isInLowPowerMode,
                onDismiss: { showPopupMenu = false }
            )
            .onHover { hovering in
                isHoveringPopover = hovering
                if hovering {
                    hideTask?.cancel()
                    hideTask = nil
                } else {
                    scheduleHideIfNeeded()
                }
            }
        }
        .onChange(of: showPopupMenu) {
            uiContext.isBatteryPopoverActive = showPopupMenu
        }
        .onDisappear {
            hideTask?.cancel()
            hideTask = nil
        }
    }

    private func scheduleHideIfNeeded() {
        if isHoveringButton || isHoveringPopover { return }
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation { showPopupMenu = false } }
        }
    }
}
