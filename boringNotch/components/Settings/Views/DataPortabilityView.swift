//
//  DataPortabilityView.swift
//  boringNotch
//
//  Settings view for exporting plugin data.
//

import SwiftUI

struct DataPortabilityView: View {
    @Environment(\.pluginManager) private var pluginManager
    @State private var selectedFormats: [String: ExportFormat] = [:]
    @State private var exportError: String?
    @State private var exportSuccess: String?
    @State private var isExporting = false

    private var exportablePlugins: [any ExportablePlugin] {
        pluginManager?.allPlugins.compactMap { $0.underlying as? (any ExportablePlugin) } ?? []
    }

    var body: some View {
        Form {
            Section {
                Text("Export your data from any plugin in standard formats.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            if exportablePlugins.isEmpty {
                Section {
                    Text("No plugins with exportable data.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(exportablePlugins, id: \.id) { plugin in
                    pluginRow(plugin)
                }
            }

            if exportablePlugins.count > 1 {
                Section("Bulk Export") {
                    Button("Export All as JSON") {
                        exportAll(format: .json)
                    }
                    .disabled(isExporting)
                }
            }

            if let error = exportError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            if let success = exportSuccess {
                Section {
                    Label(success, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Data & Privacy")
    }

    @ViewBuilder
    private func pluginRow(_ plugin: any ExportablePlugin) -> some View {
        Section(plugin.metadata.name) {
            HStack {
                Image(systemName: plugin.metadata.icon)
                    .frame(width: 24)
                Text(plugin.metadata.description)
                    .foregroundStyle(.secondary)
                    .font(.callout)
                Spacer()
            }

            HStack {
                Picker("Format", selection: formatBinding(for: plugin)) {
                    ForEach(plugin.supportedExportFormats, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .frame(maxWidth: 200)

                Spacer()

                Button("Export") {
                    exportPlugin(plugin)
                }
                .disabled(isExporting)
            }
        }
    }

    private func formatBinding(for plugin: any ExportablePlugin) -> Binding<ExportFormat> {
        Binding(
            get: { selectedFormats[plugin.id] ?? plugin.supportedExportFormats.first ?? .json },
            set: { selectedFormats[plugin.id] = $0 }
        )
    }

    private func exportPlugin(_ plugin: any ExportablePlugin) {
        guard let pm = pluginManager else { return }
        let format = selectedFormats[plugin.id] ?? plugin.supportedExportFormats.first ?? .json
        let coordinator = ExportCoordinator(pluginManager: pm)

        isExporting = true
        exportError = nil
        exportSuccess = nil

        Task {
            do {
                try await coordinator.exportPlugin(plugin, format: format)
                exportSuccess = "\(plugin.metadata.name) exported successfully."
            } catch {
                exportError = "Export failed: \(error.localizedDescription)"
            }
            isExporting = false
        }
    }

    private func exportAll(format: ExportFormat) {
        guard let pm = pluginManager else { return }
        let coordinator = ExportCoordinator(pluginManager: pm)

        isExporting = true
        exportError = nil
        exportSuccess = nil

        Task {
            do {
                try await coordinator.exportAll(format: format)
                exportSuccess = "All plugins exported successfully."
            } catch {
                exportError = "Export failed: \(error.localizedDescription)"
            }
            isExporting = false
        }
    }
}
