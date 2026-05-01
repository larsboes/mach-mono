//
//  PluginMenuBarItems.swift
//  boringNotch
//
//  Renders active plugin contributions inside the app's MenuBarExtra dropdown.
//

import SwiftUI

/// Reads the plugin manager from the environment and emits menu items for every
/// active plugin that has a `menuBarView()` implementation.
struct PluginMenuBarItems: View {
    @Environment(\.pluginManager) private var pluginManager

    var body: some View {
        if let pm = pluginManager {
            let menuPlugins = pm.activePlugins.filter { $0.hasMenuBarContent }
            if !menuPlugins.isEmpty {
                ForEach(menuPlugins) { plugin in
                    pm.menuBarView(for: plugin.id)
                }
                Divider()
            }
        }
    }
}
