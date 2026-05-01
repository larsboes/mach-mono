//
//  PluginOrderSettingsView.swift
//  boringNotch
//
//  Settings view for reordering and enabling/disabling plugins.
//

import SwiftUI

struct PluginOrderSettingsView: View {
    @Environment(\.pluginManager) private var pluginManager

    /// Ordered list of plugin IDs, kept in sync with PluginManager.pluginOrder.
    @State private var orderedIDs: [String] = []

    var body: some View {
        Form {
            Section {
                Text("Drag to reorder how plugins appear in the notch tab bar. Disabled plugins are hidden but retain their settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Plugins") {
                List {
                    ForEach(rowItems, id: \.id) { item in
                        pluginRow(item)
                    }
                    .onMove { from, to in
                        orderedIDs.move(fromOffsets: from, toOffset: to)
                        pluginManager?.reorderPlugins(orderedIDs)
                    }
                }
                .listStyle(.plain)
                .frame(minHeight: CGFloat(rowItems.count) * 44)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Plugins")
        .onAppear { syncOrder() }
        .onChange(of: pluginManager?.allPlugins.count) { syncOrder() }
    }

    // MARK: - Helpers

    private struct PluginRow: Identifiable {
        let id: String
        let name: String
        let icon: String
        var isEnabled: Bool
    }

    private var rowItems: [PluginRow] {
        guard let pm = pluginManager else { return [] }
        return orderedIDs.compactMap { id in
            guard let plugin = pm.allPlugins.first(where: { $0.id == id }) else { return nil }
            return PluginRow(id: id, name: plugin.metadata.name, icon: plugin.metadata.icon, isEnabled: plugin.isEnabled)
        }
    }

    @ViewBuilder
    private func pluginRow(_ item: PluginRow) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .frame(width: 22, alignment: .center)
                .foregroundStyle(.secondary)

            Text(item.name)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: enabledBinding(for: item.id))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .contentShape(Rectangle())
    }

    private func enabledBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { pluginManager?.isPluginEnabled(id: id) ?? false },
            set: { enabled in
                Task {
                    if enabled {
                        try? await pluginManager?.enablePlugin(id)
                    } else {
                        await pluginManager?.disablePlugin(id)
                    }
                }
            }
        )
    }

    private func syncOrder() {
        guard let pm = pluginManager else { return }
        let current = Set(orderedIDs)
        let fresh = pm.allPlugins.map(\.id)
        // Only resync if the set changed (preserves drag order)
        if Set(fresh) != current {
            orderedIDs = fresh
        }
    }
}
