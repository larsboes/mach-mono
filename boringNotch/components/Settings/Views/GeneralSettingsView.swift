//
//  GeneralSettingsView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import LaunchAtLogin
import SwiftUI

struct GeneralSettings: View {
    @State private var screens: [(uuid: String, name: String)] = NSScreen.screens.compactMap { screen in
        guard let uuid = screen.displayUUID else { return nil }
        return (uuid, screen.localizedName)
    }
    @Environment(\.bindableSettings) var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Toggle(isOn: $settings.menubarIcon) {
                    Text("Show menu bar icon")
                }
                .tint(.effectiveAccent(from: settings))
                LaunchAtLogin.Toggle("Launch at login")
                .tint(.effectiveAccent(from: settings))
                Toggle(isOn: $settings.showOnAllDisplays) {
                    Text("Show on all displays")
                }
                .onChange(of: settings.showOnAllDisplays) { _, _ in
                    NotificationCenter.default.post(
                        name: Notification.Name.showOnAllDisplaysChanged, object: nil)
                }
                Picker("Preferred display", selection: $settings.preferredScreenUUID) {
                    ForEach(screens, id: \.uuid) { screen in
                        Text(screen.name).tag(screen.uuid as String?)
                    }
                }
                .onChange(of: NSScreen.screens) { _, _ in
                    screens = NSScreen.screens.compactMap { screen in
                        guard let uuid = screen.displayUUID else { return nil }
                        return (uuid, screen.localizedName)
                    }
                }
                .disabled(settings.showOnAllDisplays)
                
                Toggle(isOn: $settings.automaticallySwitchDisplay) {
                    Text("Automatically switch displays")
                }
                    .onChange(of: settings.automaticallySwitchDisplay) { _, _ in
                        NotificationCenter.default.post(
                            name: Notification.Name.automaticallySwitchDisplayChanged, object: nil)
                    }
                    .disabled(settings.showOnAllDisplays)
            } header: {
                Text("System features")
            }

            Section {
                Picker(
                    selection: $settings.notchHeightMode,
                    label:
                        Text("Notch height on notch displays")
                ) {
                    Text("Match real notch height")
                        .tag(WindowHeightMode.matchRealNotchSize)
                    Text("Match menu bar height")
                        .tag(WindowHeightMode.matchMenuBar)
                    Text("Custom height")
                        .tag(WindowHeightMode.custom)
                }
                .onChange(of: settings.notchHeightMode) { _, _ in
                    switch settings.notchHeightMode {
                    case .matchRealNotchSize:
                        // Get the actual notch height from the built-in display
                        settings.notchHeight = getRealNotchHeight()
                    case .matchMenuBar:
                        settings.notchHeight = 43
                    case .custom:
                        settings.notchHeight = 38
                    }
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged, object: nil)
                }
                if settings.notchHeightMode == .custom {
                    Slider(value: $settings.notchHeight, in: 15...45, step: 1) {
                        Text("Custom notch size - \(settings.notchHeight, specifier: "%.0f")")
                    }
                    .onChange(of: settings.notchHeight) { _, _ in
                        NotificationCenter.default.post(
                            name: Notification.Name.notchHeightChanged, object: nil)
                    }
                }
                Picker("Notch height on non-notch displays", selection: $settings.nonNotchHeightMode) {
                    Text("Match menubar height")
                        .tag(WindowHeightMode.matchMenuBar)
                    Text("Custom height")
                        .tag(WindowHeightMode.custom)
                }
                .onChange(of: settings.nonNotchHeightMode) { _, _ in
                    switch settings.nonNotchHeightMode {
                    case .matchMenuBar:
                        settings.nonNotchHeight = 23
                    case .matchRealNotchSize, .custom:
                        settings.nonNotchHeight = 23
                    }
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged, object: nil)
                }
                if settings.nonNotchHeightMode == .custom {
                    // Custom binding to skip values 1-14 (jump from 0 to 10)
                    let sliderValue = Binding<Double>(
                        get: { 
                            settings.nonNotchHeight == 0 ? 0 : settings.nonNotchHeight - 14
                        },
                        set: { newValue in
                            let oldValue = settings.nonNotchHeight
                            settings.nonNotchHeight = newValue == 0 ? 0 : newValue + 14
                            if oldValue != settings.nonNotchHeight {
                                NotificationCenter.default.post(
                                    name: Notification.Name.notchHeightChanged, object: nil)
                            }
                        }
                    )
                    
                    Slider(value: sliderValue, in: 0...26, step: 1) {
                        Text("Custom notch size - \(settings.nonNotchHeight, specifier: "%.0f")")
                    }
                }
            } header: {
                Text("Notch sizing")
            }
            
            Section {
                Toggle(isOn: $settings.useInactiveNotchHeight) {
                    Text("Use smaller height when inactive")
                }
                .onChange(of: settings.useInactiveNotchHeight) { _, _ in
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged, object: nil)
                }

                if settings.useInactiveNotchHeight {
                    InactiveNotchHeightSlider(maxHeight: settings.nonNotchHeight)
                }
            } header: {
                Text("Inactive notch sizing (For non-notch displays)")
            }

            NotchBehaviour()

            gestureControls()
        }
        .toolbar {
            Button("Quit app") {
                NSApp.terminate(self)
            }
            .controlSize(.extraLarge)
        }
        .accentColor(.effectiveAccent(from: settings))
        .navigationTitle("General")
        .onChange(of: settings.openNotchOnHover) { _, _ in
            if !settings.openNotchOnHover {
                settings.enableGestures = true
            }
        }
    }

    @ViewBuilder
    func gestureControls() -> some View {
        @Bindable var settings = settings
        Section {
            Toggle(isOn: $settings.enableGestures) {
                Text("Enable gestures")
            }
                .disabled(!settings.openNotchOnHover)
            if settings.enableGestures {
                Toggle("Change media with horizontal gestures", isOn: .constant(false))
                    .disabled(true)
                Toggle(isOn: $settings.closeGestureEnabled) {
                    Text("Close gesture")
                }
                Slider(value: $settings.gestureSensitivity, in: 100...300, step: 100) {
                    HStack {
                        Text("Gesture sensitivity")
                        Spacer()
                        Text(
                            settings.gestureSensitivity == 100
                                ? "High" : settings.gestureSensitivity == 200 ? "Medium" : "Low"
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            HStack {
                Text("Gesture control")
                customBadge(text: "Beta")
            }
        } footer: {
            Text(
                "Two-finger swipe up on notch to close, two-finger swipe down on notch to open when **Open notch on hover** option is disabled"
            )
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
    }

    @ViewBuilder
    func NotchBehaviour() -> some View {
        @Bindable var settings = settings
        Section {
            Toggle(isOn: $settings.openNotchOnHover) {
                Text("Open notch on hover")
            }
            Toggle(isOn: $settings.enableHaptics) {
                    Text("Enable haptic feedback")
            }
            Toggle("Remember last tab", isOn: $settings.openLastTabByDefault)
            if settings.openNotchOnHover {
                Slider(value: $settings.minimumHoverDuration, in: 0...1, step: 0.1) {
                    HStack {
                        Text("Hover delay")
                        Spacer()
                        Text("\(settings.minimumHoverDuration, specifier: "%.1f")s")
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: settings.minimumHoverDuration) { _, _ in
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged, object: nil)
                }
            }
            
            Slider(value: $settings.sneakPeakDuration, in: 0.5...5, step: 0.5) {
                HStack {
                    Text("Sneak peak duration")
                    Spacer()
                    Text("\(settings.sneakPeakDuration, specifier: "%.1f")s")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Notch behavior")
        }
    }
}

struct InactiveNotchHeightSlider: View {
    @State private var localValue: Double
    let maxHeight: Double
    @Environment(\.bindableSettings) var settings
    
    init(maxHeight: Double) {
        self.maxHeight = maxHeight
        self._localValue = State(initialValue: 0) // Will be updated in onAppear
    }
    
    var body: some View {
        @Bindable var settings = settings
        let effectiveMax = max(1, maxHeight)
        let clampedValue = min(localValue, effectiveMax)
        
        VStack(spacing: 8) {
            HStack {
                Text("Inactive notch height")
                Spacer()
                Text("\(Int(clampedValue))")
                    .foregroundColor(.secondary)
            }
            
            Slider(value: Binding(
                get: { clampedValue },
                set: { newValue in
                    localValue = newValue
                }
            ), in: 1...effectiveMax, step: 1)
                .onChange(of: localValue) { _, newValue in
                    let finalValue = min(newValue, effectiveMax)
                    settings.inactiveNotchHeight = finalValue
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged,
                        object: nil
                    )
                }
        }
        .onAppear {
            localValue = settings.inactiveNotchHeight
        }
    }
}
