//
//  AxonSettingsView.swift
//  NotchAxonPlugin
//
//  Settings content for Axon plugin configuration.
//

import SwiftUI

public struct AxonSettingsView: View {
    @Bindable var plugin: AxonPlugin

    public init(plugin: AxonPlugin) {
        self.plugin = plugin
    }

    public var body: some View {
        Form {
            Section("Axon Connection") {
                TextField("Status Daemon Port", value: $plugin.statusPort, format: .number)
                    .help("Default loopback port for axon-status is 8082")

                Picker("Refresh Interval", selection: $plugin.pollIntervalSeconds) {
                    Text("10 seconds").tag(10)
                    Text("15 seconds").tag(15)
                    Text("30 seconds").tag(30)
                    Text("60 seconds").tag(60)
                }
            }

            Section("Notch Appearance") {
                Toggle("Show in Closed Notch", isOn: $plugin.showInClosedNotch)
                Toggle("Trigger SneakPeek for Imminent Events (<15m)", isOn: $plugin.enableSneakPeek)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
