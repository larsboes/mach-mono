//
//  SettingsView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//  Modified by Arsh Anwar
//

import Sparkle
import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = "General"
    @State private var accentColorUpdateTrigger = UUID()
    @Environment(\.pluginManager) var pluginManager
    @Environment(\.settings) var settings

    let updaterController: SPUStandardUpdaterController?

    init(updaterController: SPUStandardUpdaterController? = nil) {
        self.updaterController = updaterController
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                NavigationLink(value: "General") {
                    Label("General", systemImage: "gear")
                }
                NavigationLink(value: "Appearance") {
                    Label("Appearance", systemImage: "eye")
                }
                NavigationLink(value: "Media") {
                    Label("Media", systemImage: "play.laptopcomputer")
                }
                NavigationLink(value: "Calendar") {
                    Label("Calendar", systemImage: "calendar")
                }
                NavigationLink(value: "Weather") {
                    Label("Weather", systemImage: "cloud.sun.fill")
                }
                NavigationLink(value: "Habit Tracker") {
                    Label("Habit Tracker", systemImage: "checkmark.circle.fill")
                }
                NavigationLink(value: "Pomodoro") {
                    Label("Pomodoro", systemImage: "timer")
                }
                NavigationLink(value: "Notifications") {
                    Label("Notifications", systemImage: "bell.badge")
                }
                NavigationLink(value: "HUD") {
                    Label("HUDs", systemImage: "dial.medium.fill")
                }
                NavigationLink(value: "Battery") {
                    Label("Battery", systemImage: "battery.100.bolt")
                }
                NavigationLink(value: "Bluetooth") {
                    Label("Bluetooth", systemImage: "antenna.radiowaves.left.and.right")
                }
                NavigationLink(value: "Shelf") {
                    Label("Shelf", systemImage: "books.vertical")
                }
                NavigationLink(value: "Plugins") {
                    Label("Plugins", systemImage: "puzzlepiece.extension")
                }
                NavigationLink(value: "Shortcuts") {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                NavigationLink(value: "Data") {
                    Label("Data & Privacy", systemImage: "externaldrive")
                }
                NavigationLink(value: "Advanced") {
                    Label("Advanced", systemImage: "gearshape.2")
                }
                NavigationLink(value: "About") {
                    Label("About", systemImage: "info.circle")
                }
            }
            .listStyle(SidebarListStyle())
            .tint(.effectiveAccent(from: settings))
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(200)
        } detail: {
            Group {
                switch selectedTab {
                case "General":
                    GeneralSettings()
                case "Appearance":
                    Appearance()
                case "Media":
                    Media()
                case "Calendar":
                    CalendarSettings()
                case "Weather":
                    WeatherSettings()
                case "Habit Tracker":
                    if let pm = pluginManager {
                        pm.settingsView(for: PluginID.habitTracker)
                    } else {
                        Text("Plugin Manager unavailable")
                    }
                case "Pomodoro":
                    if let pm = pluginManager {
                        pm.settingsView(for: PluginID.pomodoro)
                    } else {
                        Text("Plugin Manager unavailable")
                    }
                case "Notifications":
                    NotificationsSettingsView()
                case "HUD":
                    HUD()
                case "Battery":
                    Charge()
                case "Bluetooth":
                    if let pm = pluginManager {
                        BluetoothSettingsView(bluetoothManager: pm.services.bluetoothManager)
                    }
                case "Shelf":
                    Shelf()
                case "Plugins":
                    PluginOrderSettingsView()
                case "Shortcuts":
                    Shortcuts()
                case "Data":
                    DataPortabilityView()
                case "Advanced":
                    Advanced()
                case "About":
                    if let controller = updaterController {
                        About(updaterController: controller)
                    } else {
                        // Fallback with a default controller
                        About(
                            updaterController: SPUStandardUpdaterController(
                                startingUpdater: false, updaterDelegate: nil,
                                userDriverDelegate: nil))
                    }
                default:
                    GeneralSettings()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 700)
        .background(Color(NSColor.windowBackgroundColor))
        .tint(.effectiveAccent(from: settings))
        .id(accentColorUpdateTrigger)
        .onReceive(NotificationCenter.default.publisher(for: .accentColorChanged)) { _ in
            accentColorUpdateTrigger = UUID()
        }
    }
}
