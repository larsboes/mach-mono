//
//  ShelfSettingsView.swift
//  machNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import SwiftUI

struct Shelf: View {
    @Environment(\.bindableSettings) var settings
    @Environment(\.pluginManager) var pluginManager

    private var quickShareService: QuickShareService? { pluginManager?.services.quickShare }

    private var selectedProvider: QuickShareProvider? {
        quickShareService?.availableProviders.first(where: { $0.id == settings.quickShareProvider })
    }

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Toggle(isOn: $settings.shelfEnabled) {
                    Text("Enable shelf")
                }
                Toggle(isOn: $settings.openShelfByDefault) {
                    Text("Open shelf by default if items are present")
                }
                Toggle(isOn: $settings.expandedDragDetection) {
                    Text("Expanded drag detection area")
                }
                Toggle(isOn: $settings.copyOnDrag) {
                    Text("Copy items on drag")
                }
                Toggle(isOn: $settings.autoRemoveShelfItems) {
                    Text("Remove from shelf after dragging")
                }

                VStack(alignment: .leading) {
                    Text("Auto-close delay: \(String(format: "%.1f", settings.shelfHoverDelay))s")
                    Slider(value: $settings.shelfHoverDelay, in: 1.0...10.0, step: 0.5) {
                        Text("Auto-close delay")
                    } minimumValueLabel: {
                        Text("1s")
                    } maximumValueLabel: {
                        Text("10s")
                    }
                }

            } header: {
                HStack {
                    Text("General")
                }
            }

            Section {
                Picker("Quick Share Service", selection: $settings.quickShareProvider) {
                    ForEach(quickShareService?.availableProviders ?? [], id: \.id) { provider in
                        HStack {
                            Group {
                                if let icon = quickShareService?.icon(for: provider.id, size: 16) {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                            .frame(width: 16, height: 16)
                            .foregroundColor(.accentColor)
                            Text(provider.id)
                        }
                        .tag(provider.id)
                    }
                }
                .pickerStyle(.menu)

                if let selectedProvider = selectedProvider {
                    HStack {
                        Group {
                            if let icon = quickShareService?.icon(for: selectedProvider.id, size: 16) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .frame(width: 16, height: 16)
                        .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Currently selected: \(selectedProvider.id)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Files dropped on the shelf will be shared via this service")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

            } header: {
                HStack {
                    Text("Quick Share")
                }
            } footer: {
                Text(
                    "Choose which service to use when sharing files from the shelf. Click the shelf button to select files, or drag files onto it to share immediately."
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Section {
                Toggle(isOn: $settings.obsidianSyncEnabled) {
                    Label("Sync notes to Obsidian", systemImage: "diamond")
                }

                if settings.obsidianSyncEnabled {
                    HStack {
                        Text(settings.obsidianVaultPath ?? "No vault selected")
                            .foregroundColor(settings.obsidianVaultPath == nil ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Choose…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            panel.message = "Select your Obsidian vault folder"
                            if panel.runModal() == .OK {
                                settings.obsidianVaultPath = panel.url?.path
                            }
                        }
                        .buttonStyle(.borderless)

                        if settings.obsidianVaultPath != nil {
                            Button(action: { settings.obsidianVaultPath = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            } header: {
                Text("Notes")
            } footer: {
                Text("When enabled, each note is written as a Markdown file inside your vault folder.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .accentColor(.effectiveAccent(from: settings))
        .navigationTitle("Shelf")
    }
}
