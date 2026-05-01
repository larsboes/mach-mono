//
//  PomodoroSettingsView.swift
//  boringNotch
//

import SwiftUI

struct PomodoroSettingsView: View {
    let plugin: PomodoroPlugin
    private var timer: PomodoroTimer { plugin.timer }
    
    @State private var workMinutes: Int
    @State private var shortBreakMinutes: Int
    @State private var longBreakMinutes: Int
    @State private var sessionsUntilLong: Int
    
    init(plugin: PomodoroPlugin) {
        self.plugin = plugin
        _workMinutes = State(initialValue: Int(plugin.timer.settings.workDuration) / 60)
        _shortBreakMinutes = State(initialValue: Int(plugin.timer.settings.shortBreakDuration) / 60)
        _longBreakMinutes = State(initialValue: Int(plugin.timer.settings.longBreakDuration) / 60)
        _sessionsUntilLong = State(initialValue: plugin.timer.settings.sessionsUntilLongBreak)
    }
    
    @Environment(\.bindableSettings) var globalSettings
    
    var body: some View {
        @Bindable var globalSettings = globalSettings
        VStack(alignment: .leading, spacing: 16) {
            Text("Pomodoro Settings")
                .font(.headline)
            
            Form {
                Section {
                    Toggle(isOn: $globalSettings.showPomodoro) {
                        Text("Enable Pomodoro Timer")
                    }
                }
                
                if globalSettings.showPomodoro {
                    Section("Durations (Minutes)") {
                        Stepper("Focus Time: \(workMinutes)", value: $workMinutes, in: 1...90)
                        Stepper("Short Break: \(shortBreakMinutes)", value: $shortBreakMinutes, in: 1...30)
                        Stepper("Long Break: \(longBreakMinutes)", value: $longBreakMinutes, in: 1...60)
                    }
                    
                    Section("Cycle") {
                        Stepper("Sessions before long break: \(sessionsUntilLong)", value: $sessionsUntilLong, in: 2...10)
                    }
                }
            }
            .formStyle(.grouped)
            .onChange(of: workMinutes) { saveSettings() }
            .onChange(of: shortBreakMinutes) { saveSettings() }
            .onChange(of: longBreakMinutes) { saveSettings() }
            .onChange(of: sessionsUntilLong) { saveSettings() }
            
            if globalSettings.showPomodoro {
                Divider()
                
                HStack {
                    VStack(alignment: .leading) {
                        let totalTime = timer.completedSessions.filter { $0.type == .work }.reduce(0) { $0 + $1.duration }
                        Text("Total Focus Time: \(Int(totalTime / 60)) min")
                        Text("Completed Sessions: \(timer.completedSessions.filter { $0.type == .work }.count)")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private func saveSettings() {
        let newSettings = PomodoroSettings(
            workDuration: TimeInterval(workMinutes * 60),
            shortBreakDuration: TimeInterval(shortBreakMinutes * 60),
            longBreakDuration: TimeInterval(longBreakMinutes * 60),
            sessionsUntilLongBreak: sessionsUntilLong
        )
        timer.updateSettings(newSettings)
    }
}
