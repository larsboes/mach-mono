//
//  BatterySettingsView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import SwiftUI

struct Charge: View {
    @Environment(\.bindableSettings) var settings
    @Environment(\.xpcHelper) var xpcHelper

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Toggle(isOn: $settings.showBatteryIndicator) {
                    Text("Show battery indicator")
                }
                Toggle(isOn: $settings.showPowerStatusNotifications) {
                    Text("Show power status notifications")
                }
            } header: {
                Text("General")
            }
            Section {
                // toggle won't show if device is wall powered device
                if deviceHasBattery() {
                    Toggle(isOn: $settings.showBatteryPercentage) {
                        Text("Show battery percentage")
                    }
                }
                Toggle(isOn: $settings.showPowerStatusIcons) {
                    Text("Show power status icons")
                }
            } header: {
                Text("Battery Information")
            }
            
            Section {
                PickerSoundAlert(sounds: SystemSoundHelper.availableSystemSounds(), sound: $settings.powerStatusNotificationSound)
                
                BatteryLevelPicker(
                    title: "Low Battery Notification",
                    level: $settings.lowBatteryNotificationLevel,
                    sounds: SystemSoundHelper.availableSystemSounds(),
                    sound: $settings.lowBatteryNotificationSound
                )
                
                BatteryLevelPicker(
                    title: "High Battery Notification",
                    level: $settings.highBatteryNotificationLevel,
                    sounds: SystemSoundHelper.availableSystemSounds(),
                    sound: $settings.highBatteryNotificationSound
                )
            } header: {
                Text("Notifications")
            }
        }
        .onAppear {
            Task { @MainActor in
                await xpcHelper?.isAccessibilityAuthorized() ?? false
            }
        }
        .accentColor(.effectiveAccent(from: settings))
        .navigationTitle("Battery")
    }
}

struct BatteryLevelPicker: View {
    let title: String
    @Binding var level: Int
    let sounds: [String]
    @Binding var sound: String
    
    var body: some View {
        HStack {
            Picker(title, selection: $level) {
                Text("Disabled").tag(0)
                ForEach(1...100, id: \.self) { level in
                    Text("\(level)%").tag(level)
                }
            }
            Divider()
            PickerSoundAlert(sounds: sounds, sound: $sound)
        }
    }
}

struct PickerSoundAlert: View {
    let sounds: [String]
    @Binding var sound: String
    
    var body: some View {
        Picker("Sound", selection: $sound) {
            Text("Disabled").tag("Disabled")
            ForEach(sounds, id: \.self) { sound in
                Text(sound).tag(sound)
            }
        }
    }
}
