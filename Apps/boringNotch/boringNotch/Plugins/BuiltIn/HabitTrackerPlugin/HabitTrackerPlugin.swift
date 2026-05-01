//
//  HabitTrackerPlugin.swift
//  boringNotch
//
//  Built-in habit tracking plugin.
//

import SwiftUI
import Combine
import Defaults

@MainActor
@Observable
final class HabitTrackerPlugin: NotchPlugin, ExportablePlugin {
    
    // MARK: - NotchPlugin
    
    let id = PluginID.habitTracker
    
    let metadata = PluginMetadata(
        name: "Habit Tracker",
        description: "Track your daily habits directly from the notch",
        icon: "checkmark.circle.fill", // Changed from checkmark.seal to checkmark.circle.fill which is standard
        version: "1.0.0",
        author: "boringNotch",
        category: .productivity
    )
    
    var isEnabled: Bool = true
    
    // Provide a dedicated data store
    let store = HabitStore()
    
    private(set) var state: PluginState = .inactive
    
    private var settings: PluginSettings?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Lifecycle
    
    func activate(context: PluginContext) async throws {
        state = .activating
        self.settings = context.settings
        state = .active
    }
    
    func deactivate() async {
        cancellables.removeAll()
        settings = nil
        state = .inactive
        isEnabled = false
    }
    
    // MARK: - UI Slots
    
    @ViewBuilder
    func closedNotchContent() -> some View {
        if isEnabled, state.isActive {
            // To be implemented: dots for today's habits
            HabitClosedView(plugin: self)
        }
    }
    
    @ViewBuilder
    func expandedPanelContent() -> some View {
        if isEnabled, state.isActive {
            // To be implemented: list of habits to tick off
            HabitExpandedView(plugin: self)
        }
    }
    
    @ViewBuilder
    func settingsContent() -> some View {
        // We always show settings so users can turn it on/off
        HabitSettingsView(plugin: self)
    }
    
    // MARK: - ExportablePlugin

    var supportedExportFormats: [ExportFormat] { [.json, .csv] }

    func exportData(format: ExportFormat) async throws -> Data {
        switch format {
        case .json:
            return try exportJSON()
        case .csv:
            return try exportCSV()
        default:
            throw ExportError.unsupportedFormat(format)
        }
    }

    private func exportJSON() throws -> Data {
        var export = [String: Any]()
        if let habitData = try? JSONEncoder().encode(store.habits),
           let habitArray = try? JSONSerialization.jsonObject(with: habitData) as? [[String: Any]] {
            export["habits"] = habitArray
        }
        if let completionData = try? JSONEncoder().encode(store.completions),
           let completionArray = try? JSONSerialization.jsonObject(with: completionData) as? [[String: Any]] {
            export["completions"] = completionArray
        }
        return try JSONSerialization.data(withJSONObject: export, options: .prettyPrinted)
    }

    private func exportCSV() throws -> Data {
        let iso = ISO8601DateFormatter()
        let habitIndex = Dictionary(uniqueKeysWithValues: store.habits.map { ($0.id, $0.title) })
        var lines = ["date,habit_id,habit_title,completed_at"]
        for completion in store.completions.sorted(by: { $0.date < $1.date }) {
            let title = habitIndex[completion.habitId].map { "\"\($0)\"" } ?? ""
            lines.append("\(iso.string(from: completion.date)),\(completion.habitId),\(title),\(iso.string(from: completion.completedAt))")
        }
        guard let data = lines.joined(separator: "\n").data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }
}
