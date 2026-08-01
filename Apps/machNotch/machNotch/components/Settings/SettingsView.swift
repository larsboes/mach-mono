//
//  SettingsView.swift
//  machNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//  Modified by Arsh Anwar
//

import Sparkle
import SwiftUI

struct SettingsCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let systemImage: String
}

struct SettingsView: View {
    private static let systemCategories: [SettingsCategory] = [
        .init(id: "General", name: "General", systemImage: "gear"),
        .init(id: "Appearance", name: "Appearance", systemImage: "eye"),
        .init(id: "HUD", name: "HUDs", systemImage: "dial.medium.fill"),
        .init(id: "Bluetooth", name: "Bluetooth", systemImage: "antenna.radiowaves.left.and.right"),
        .init(id: "Plugins", name: "Plugins", systemImage: "puzzlepiece.extension"),
        .init(id: "Shortcuts", name: "Shortcuts", systemImage: "keyboard"),
        .init(id: "Data", name: "Data & Privacy", systemImage: "externaldrive"),
        .init(id: "Advanced", name: "Advanced", systemImage: "gearshape.2"),
        .init(id: "About", name: "About", systemImage: "info.circle"),
    ]

    @State private var selectedTab = "General"
    @State private var searchText = ""
    @State private var accentColorUpdateTrigger = UUID()
    @Environment(\.pluginManager) var pluginManager
    @Environment(\.settings) var settings

    let updaterController: SPUStandardUpdaterController?

    init(updaterController: SPUStandardUpdaterController? = nil) {
        self.updaterController = updaterController
    }

    var pluginCategories: [SettingsCategory] {
        guard let pm = pluginManager else { return [] }
        return pm.allPluginSummaries
            .filter { $0.hasSettingsContent }
            .map { plugin in
                SettingsCategory(
                    id: plugin.id,
                    name: plugin.metadata.name,
                    systemImage: plugin.metadata.icon
                )
            }
    }

    private func filtered(_ categories: [SettingsCategory]) -> [SettingsCategory] {
        if searchText.isEmpty { return categories }
        return categories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredSystem: [SettingsCategory] { filtered(Self.systemCategories) }
    var filteredPlugins: [SettingsCategory] { filtered(pluginCategories) }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                if !filteredSystem.isEmpty {
                    ForEach(filteredSystem) { category in
                        NavigationLink(value: category.id) {
                            Label(category.name, systemImage: category.systemImage)
                        }
                    }
                }

                if !filteredSystem.isEmpty && !filteredPlugins.isEmpty {
                    Divider()
                }

                if !filteredPlugins.isEmpty {
                    ForEach(filteredPlugins) { category in
                        NavigationLink(value: category.id) {
                            Label(category.name, systemImage: category.systemImage)
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search settings")
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
                case "HUD":
                    HUD()
                case "Bluetooth":
                    if let pm = pluginManager {
                        BluetoothSettingsView(bluetoothManager: pm.services.bluetoothManager)
                    } else {
                        Text("Plugin Manager unavailable")
                    }
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
                    if let pm = pluginManager, pm.hasPlugin(id: selectedTab) {
                        pm.settingsView(for: selectedTab)
                    } else {
                        GeneralSettings()
                    }
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
