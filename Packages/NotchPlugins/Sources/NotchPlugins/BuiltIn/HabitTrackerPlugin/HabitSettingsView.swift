//
//  HabitSettingsView.swift
//  machNotch
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct HabitSettingsView: View {
    let plugin: HabitTrackerPlugin
    private var store: HabitStore { plugin.store }

    @Environment(\.bindableSettings) var settings

    var body: some View {
        @Bindable var settings = settings

        // List gives proper drag handles for .onMove on macOS; Form does not.
        List {
            Section {
                Toggle(isOn: $settings.showHabitTracker) {
                    Text("Enable Habit Tracker")
                }
            }

            if settings.showHabitTracker {
                Section("Habits") {
                    if store.habits.isEmpty {
                        Text("No habits yet — add them from the notch.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    } else {
                        ForEach(store.habits) { habit in
                            HStack(spacing: 10) {
                                Image(systemName: habit.symbol)
                                    .foregroundStyle(habit.color)
                                    .frame(width: 20, alignment: .center)
                                Text(habit.title)
                                    .foregroundStyle(habit.isActive ? .primary : .secondary)
                                Spacer()
                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { habit.isActive },
                                        set: { newValue in
                                            var modified = habit
                                            modified.isActive = newValue
                                            store.updateHabit(modified)
                                        }
                                    )
                                )
                                .labelsHidden()
                            }
                        }
                        .onMove { from, to in store.reorderHabits(from: from, to: to) }
                    }
                }

                Section("Statistics") {
                    LabeledContent("Total Habits", value: "\(store.habits.count)")
                    LabeledContent("Total Completions", value: "\(store.completions.count)")
                }

                Section("Export Data") {
                    Button("Export as JSON") { exportData(format: .json) }
                    Button("Export as CSV") { exportData(format: .csv) }
                }
            }
        }
        .frame(width: 420)
    }

    private func exportData(format: ExportFormat) {
        Task { @MainActor in
            guard let data = try? await plugin.exportData(format: format) else { return }
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "habits.\(format.rawValue)"
            panel.allowedContentTypes = [format == .json ? .json : .commaSeparatedText]
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
