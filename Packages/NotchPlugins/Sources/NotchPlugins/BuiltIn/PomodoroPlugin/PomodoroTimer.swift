//
//  PomodoroTimer.swift
//  machNotch
//
//  Core timer logic for the Pomodoro plugin.
//

import Foundation
import SwiftUI

@MainActor
@Observable
public final class PomodoroTimer {

    // MARK: - State Properties

    public private(set) var currentType: SessionType = .work
    public private(set) var isRunning: Bool = false
    public private(set) var timeRemaining: TimeInterval = 0
    public private(set) var completedWorkSessions: Int = 0
    public var eventBus: PluginEventBus?

    public var settings: PomodoroSettings
    public var completedSessions: [PomodoroSession] = []

    // MARK: - Internal

    private var timerTask: Task<Void, Error>?
    private let fileURL: URL

    // Computed for UI
    public var progress: Double {
        let total = durationForSession(type: currentType)
        guard total > 0 else { return 0 }
        return 1.0 - (timeRemaining / total)
    }

    public var timeRemainingString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            timerTask?.cancel()
        }
    }

    // MARK: - Initialization

    public init() {
        self.settings = .default

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("machNotch")

        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        }
        self.fileURL = appDir.appendingPathComponent("pomodoro.json")

        load()
        resetTimer(for: .work)
    }

    // MARK: - Persistence

    private struct StorageStruct: Codable {
        var settings: PomodoroSettings
        var completedSessions: [PomodoroSession]
    }

    public func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            let storage = try JSONDecoder().decode(StorageStruct.self, from: data)
            self.settings = storage.settings
            self.completedSessions = storage.completedSessions
        } catch {
            print("Failed to load pomodoro: \(error.localizedDescription)")
        }
    }

    public func save() {
        do {
            let storage = StorageStruct(settings: settings, completedSessions: completedSessions)
            let data = try JSONEncoder().encode(storage)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save pomodoro: \(error.localizedDescription)")
        }
    }

    // MARK: - Timer Control

    public func updateSettings(_ newSettings: PomodoroSettings) {
        let wasRunning = isRunning
        stop()

        self.settings = newSettings
        save()

        resetTimer(for: currentType)
        if wasRunning {
            start()
        }
    }

    private func emitStateChange() {
        eventBus?.emit(PomodoroPhaseChangedEvent(
            isRunning: isRunning,
            sessionType: currentType.rawValue,
            timeRemaining: timeRemaining
        ))
    }

    public func start() {
        guard !isRunning, timeRemaining > 0 else { return }
        isRunning = true
        emitStateChange()

        timerTask = Task {
            while !Task.isCancelled && isRunning {
                try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

                guard !Task.isCancelled else { break }

                if timeRemaining > 0 {
                    timeRemaining -= 1
                    emitStateChange()
                }

                if timeRemaining <= 0 {
                    handleSessionComplete()
                    break
                }
            }
        }
    }

    public func stop() {
        isRunning = false
        timerTask?.cancel()
        timerTask = nil
        emitStateChange()
    }

    public func reset() {
        stop()
        resetTimer(for: currentType)
    }

    public func skip() {
        stop()
        handleSessionComplete()
    }

    // MARK: - Internal Session Logic

    private func resetTimer(for type: SessionType) {
        currentType = type
        timeRemaining = durationForSession(type: type)
        emitStateChange()
    }

    private func durationForSession(type: SessionType) -> TimeInterval {
        switch type {
        case .work: return settings.workDuration
        case .shortBreak: return settings.shortBreakDuration
        case .longBreak: return settings.longBreakDuration
        }
    }

    private func handleSessionComplete() {
        isRunning = false

        // Record session
        let duration = durationForSession(type: currentType)
        let session = PomodoroSession(type: currentType, duration: duration)
        completedSessions.append(session)
        save()

        // Determine next phase
        if currentType == .work {
            completedWorkSessions += 1
            if completedWorkSessions >= settings.sessionsUntilLongBreak {
                resetTimer(for: .longBreak)
                completedWorkSessions = 0
            } else {
                resetTimer(for: .shortBreak)
            }
        } else {
            // Break is over, back to work
            resetTimer(for: .work)
        }
    }
}
