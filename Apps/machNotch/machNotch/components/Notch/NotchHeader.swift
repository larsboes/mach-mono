//
//  NotchHeader.swift
//  machNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import SwiftUI

struct NotchHeader: View {
    @Environment(NotchViewModel.self) var vm
    @Environment(\.settings) var settings
    @Environment(\.pluginManager) var pluginManager
    @Environment(NotchViewCoordinator.self) var coordinator
    @Environment(\.showSettingsWindow) var showSettingsWindow
    @Environment(\.contentProgress) var contentProgress

    var body: some View {
        HStack(spacing: 0) {
            leadingContent
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentReveal(progress: contentProgress, staggerIndex: 0)
                .zIndex(2)
            
            notchOverlay
            
            trailingControls
                .padding(4)
                .font(.system(.headline, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .contentReveal(progress: contentProgress, staggerIndex: 1)
                .zIndex(2)
        }
        .padding(.horizontal, 20)
        .foregroundColor(.gray)
        .environment(vm)
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
    }

    // MARK: - Leading

    @ViewBuilder
    private var leadingContent: some View {
        if let shelf = pluginManager?.services.shelf, (!shelf.isEmpty || coordinator.alwaysShowTabs) && settings.shelfEnabled {
            TabSelectionView()
                .padding(.leading, 8)
        } else if vm.phase.isVisible {
            EmptyView()
        }
    }

    // MARK: - Notch Overlay

    @ViewBuilder
    private var notchOverlay: some View {
        let currentScreen = NSScreen.screen(withUUID: coordinator.selectedScreenUUID)
        let hasHardwareNotch = (currentScreen?.safeAreaInsets.top ?? 0) > 0

        if vm.phase.isVisible && hasHardwareNotch {
            if !settings.liquidGlassEffect {
                Rectangle()
                    .fill(.black)
                    .frame(width: vm.closedNotchSize.width + 64) // Added 64pt safety margin (32pt each side)
                    .mask { NotchShape() }
                    .allowsHitTesting(false)
            } else {
                Color.clear
                    .frame(width: vm.closedNotchSize.width + 64, height: 1)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Trailing Controls

    @ViewBuilder
    private var trailingControls: some View {
        @Bindable var coordinator = coordinator
        if vm.phase.isVisible {
            if coordinator.sneakPeek.type.isHUD && coordinator.sneakPeek.show && settings.showOpenNotchHUD {
                OpenNotchHUD(type: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .padding(.trailing, 8)
            } else {
                HStack(spacing: 4) {
                    headerButtons
                }
                .padding(.leading, 8) // Extra buffer from the notch area
            }
        }
    }

    @ViewBuilder
    private var headerButtons: some View {
        if settings.showHabitTracker {
            HeaderButton(icon: "checkmark.circle.fill", isActive: vm.currentView == .habitTracker) {
                vm.navigate(to: vm.currentView == .habitTracker ? .home : .habitTracker)
            }
        }
        if settings.showPomodoro {
            HeaderButton(icon: "timer", isActive: vm.currentView == .pomodoro) {
                vm.navigate(to: vm.currentView == .pomodoro ? .home : .pomodoro)
            }
        }
        if settings.showTeleprompter {
            HeaderButton(icon: "text.justify.left", isActive: vm.currentView == .teleprompter) {
                vm.navigate(to: vm.currentView == .teleprompter ? .home : .teleprompter)
            }
        }
        if pluginManager?.hasPlugin(id: PluginID.systemStats) == true {
            HeaderButton(icon: "gauge.with.dots.needle.50percent", isActive: vm.currentView == .systemStats) {
                vm.navigate(to: vm.currentView == .systemStats ? .home : .systemStats)
            }
        }
        if settings.showMirror {
            HeaderActionButton(icon: "web.camera") {
                vm.toggleCameraPreview()
            }
        }
        if settings.showBatteryIndicator,
           let batteryPlugin = pluginManager?.plugin(id: PluginID.battery, as: BatteryPlugin.self) {
            batteryPlugin.headerContent()
        }
        if settings.settingsIconInNotch {
            HeaderActionButton(icon: "gear") {
                showSettingsWindow()
            }
        }
    }
}

#Preview {
    NotchHeader().environment(NotchViewModel())
}
