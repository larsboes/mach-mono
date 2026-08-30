//
//  PluginOrderSettingsView.swift
//  machNotch
//
//  Settings view for reordering and enabling/disabling plugins.
//

import NotchCore
import SwiftUI

struct PluginOrderSettingsView: View {
    @Environment(\.pluginManager) private var pluginManager

    /// Ordered list of plugin IDs, kept in sync with PluginManager.pluginOrder.
    @State private var orderedIDs: [String] = []

    var body: some View {
        Form {
            Section {
                Text(
                    "Drag to reorder how plugins appear in the notch tab bar. Disabled plugins are hidden but retain their settings."
                )
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
        .onAppear {
            // Re-read which overlapping apps are installed before drawing the rows.
            pluginManager?.refreshExternalApps()
            syncOrder()
        }
        .onChange(of: pluginManager?.allPluginSummaries.count) { syncOrder() }
    }

    // MARK: - Helpers

    private struct PluginRow: Identifiable {
        let id: String
        let name: String
        let icon: String
        var isEnabled: Bool
        /// Set when an installed third-party app already covers this plugin.
        var coexistence: ResolvedCoexistence?
    }

    private var rowItems: [PluginRow] {
        guard let pm = pluginManager else { return [] }
        return orderedIDs.compactMap { id in
            guard let plugin = pm.summary(id: id) else { return nil }
            return PluginRow(
                id: id,
                name: plugin.metadata.name,
                icon: plugin.metadata.icon,
                isEnabled: plugin.isEnabled,
                // Only surfaced once the other app is actually installed, so the
                // list never advertises software the user does not have.
                coexistence: plugin.coexistence.flatMap { $0.isRedundant ? $0 : nil })
        }
    }

    @ViewBuilder
    private func pluginRow(_ item: PluginRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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

            if let coexistence = item.coexistence, item.isEnabled {
                coexistenceNote(coexistence, pluginID: item.id)
            }
        }
        .contentShape(Rectangle())
    }

    /// Names the app that already does this job, and offers to step aside.
    @ViewBuilder
    private func coexistenceNote(_ coexistence: ResolvedCoexistence, pluginID: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "arrow.triangle.branch")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .center)

            Text(coexistence.summaryText ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if coexistence.offersDisable {
                Button("Turn off") {
                    Task { await pluginManager?.disablePlugin(pluginID) }
                }
                .buttonStyle(.link)
                .font(.caption)
            }

            Spacer(minLength: 0)
        }
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
        let fresh = pm.allPluginSummaries.map(\.id)
        // Only resync if the set changed (preserves drag order)
        if Set(fresh) != current {
            orderedIDs = fresh
        }
    }
}
