//
//  PomodoroPlugin.swift
//  machNotch
//
//  Built-in Pomodoro plugin wrapper.
//

import Defaults
import SwiftUI

@MainActor
@Observable
public final class PomodoroPlugin: NotchPlugin, ExportablePlugin {

    // MARK: - NotchPlugin

    public let id = PluginID.pomodoro

    public let metadata = PluginMetadata(
        name: "Pomodoro Timer",
        description: "Focus sessions right from the notch",
        icon: "timer",
        version: "1.0.0",
        author: "machNotch",
        category: .productivity
    )

    public var isEnabled: Bool = true

    // Dedicated state
    public let timer = PomodoroTimer()

    public private(set) var state: PluginState = .inactive

    private var settings: PluginSettings?
    private var eventBus: PluginEventBus?

    // MARK: - Initialization

    public init() {}

    // MARK: - Lifecycle

    public func activate(context: PluginContext) async throws {
        state = .activating
        self.settings = context.settings
        self.eventBus = context.eventBus
        self.timer.eventBus = context.eventBus
        state = .active
    }

    public func deactivate() async {
        timer.stop()
        settings = nil
        eventBus = nil
        state = .inactive
        isEnabled = false
    }

    // MARK: - UI Slots

    @ViewBuilder
    public func closedNotchContent() -> some View {
        if isEnabled, state.isActive {
            PomodoroClosedView(plugin: self)
        }
    }

    @ViewBuilder
    public func expandedPanelContent() -> some View {
        if isEnabled, state.isActive {
            PomodoroExpandedView(plugin: self)
        }
    }

    @ViewBuilder
    public func settingsContent() -> some View {
        PomodoroSettingsView(plugin: self)
    }

    @ViewBuilder
    public func menuBarView() -> some View {
        if isEnabled, state.isActive, timer.isRunning {
            Text("\(timer.currentType.rawValue): \(timer.timeRemainingString)")
        }
    }

    // MARK: - ExportablePlugin

    public var supportedExportFormats: [ExportFormat] { [.json, .csv] }

    public func exportData(format: ExportFormat) async throws -> Data {
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
        if let data = try? JSONEncoder().encode(timer.completedSessions),
            let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        {
            export["completedSessions"] = array
            let workSessions = timer.completedSessions.filter { $0.type == .work }.count
            let totalWorkTime = timer.completedSessions.filter { $0.type == .work }.reduce(0) { $0 + $1.duration }
            export["stats"] = [
                "totalWorkSessions": workSessions,
                "totalWorkTimeMinutes": totalWorkTime / 60.0,
            ]
        }
        return try JSONSerialization.data(withJSONObject: export, options: .prettyPrinted)
    }

    private func exportCSV() throws -> Data {
        let iso = ISO8601DateFormatter()
        var lines = ["completed_at,type,duration_minutes"]
        for session in timer.completedSessions.sorted(by: { $0.completedAt < $1.completedAt }) {
            let minutes = String(format: "%.1f", session.duration / 60.0)
            lines.append("\(iso.string(from: session.completedAt)),\(session.type.rawValue),\(minutes)")
        }
        guard let data = lines.joined(separator: "\n").data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }
}
