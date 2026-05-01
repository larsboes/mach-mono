//
//  PomodoroModels.swift
//  boringNotch
//
//  Data models for the Pomodoro plugin.
//

import Foundation
import SwiftUI

/// Defines the phase of a Pomodoro session
enum SessionType: String, Codable, Equatable, CaseIterable {
    case work = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
    
    var color: Color {
        switch self {
        case .work: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
}

/// Represents a completed session for history/export
struct PomodoroSession: Identifiable, Codable, Equatable {
    var id: UUID
    var
    type: SessionType
    var duration: TimeInterval // Scheduled duration in seconds
    var completedAt: Date
    
    init(id: UUID = UUID(), type: SessionType, duration: TimeInterval, completedAt: Date = Date()) {
        self.id = id
        self.type = type
        self.duration = duration
        self.completedAt = completedAt
    }
}

/// Configuration settings for the timer
struct PomodoroSettings: Codable, Equatable {
    var workDuration: TimeInterval // seconds
    var shortBreakDuration: TimeInterval
    var longBreakDuration: TimeInterval
    var sessionsUntilLongBreak: Int
    
    // Default 25/5/15 layout
    static let `default` = PomodoroSettings(
        workDuration: 25 * 60,
        shortBreakDuration: 5 * 60,
        longBreakDuration: 15 * 60,
        sessionsUntilLongBreak: 4
    )
}
