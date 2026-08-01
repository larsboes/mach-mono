//
//  PomodoroModels.swift
//  machNotch
//
//  Data models for the Pomodoro plugin.
//

import Foundation
import SwiftUI

/// Defines the phase of a Pomodoro session
public enum SessionType: String, Codable, Equatable, CaseIterable {
    case work = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"

    public var color: Color {
        switch self {
        case .work: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
}

/// Represents a completed session for history/export
public struct PomodoroSession: Identifiable, Codable, Equatable {
    public var id: UUID
    public var type: SessionType
    public var duration: TimeInterval  // Scheduled duration in seconds
    public var completedAt: Date

    public init(id: UUID = UUID(), type: SessionType, duration: TimeInterval, completedAt: Date = Date()) {
        self.id = id
        self.type = type
        self.duration = duration
        self.completedAt = completedAt
    }
}

/// Configuration settings for the timer
public struct PomodoroSettings: Codable, Equatable {
    public var workDuration: TimeInterval  // seconds
    public var shortBreakDuration: TimeInterval
    public var longBreakDuration: TimeInterval
    public var sessionsUntilLongBreak: Int

    public init(workDuration: TimeInterval, shortBreakDuration: TimeInterval, longBreakDuration: TimeInterval, sessionsUntilLongBreak: Int) {
        self.workDuration = workDuration
        self.shortBreakDuration = shortBreakDuration
        self.longBreakDuration = longBreakDuration
        self.sessionsUntilLongBreak = sessionsUntilLongBreak
    }

    // Default 25/5/15 layout
    public static let `default` = PomodoroSettings(
        workDuration: 25 * 60,
        shortBreakDuration: 5 * 60,
        longBreakDuration: 15 * 60,
        sessionsUntilLongBreak: 4
    )
}
