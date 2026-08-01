//
//  HabitModels.swift
//  machNotch
//
//  Data models for the Habit Tracker plugin.
//

import Foundation
import SwiftUI

/// Defines a single habit to be tracked.
public struct Habit: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var title: String
    public var symbol: String
    public var colorHex: String
    public var createdAt: Date
    public var isActive: Bool

    public init(
        id: UUID = UUID(), title: String, symbol: String = "circle.fill", colorHex: String = "#FFFFFF",
        createdAt: Date = Date(), isActive: Bool = true
    ) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.isActive = isActive
    }

    public var color: Color {
        Color(hex: colorHex)
    }
}

/// A record of a habit being completed on a specific date.
public struct HabitCompletion: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var habitId: UUID
    public var date: Date  // Canonicalized to start of day
    public var completedAt: Date

    public init(id: UUID = UUID(), habitId: UUID, date: Date, completedAt: Date = Date()) {
        self.id = id
        self.habitId = habitId
        self.date = Calendar.current.startOfDay(for: date)
        self.completedAt = completedAt
    }
}

/// Aggregated stats for a habit.
public struct HabitStats {
    public let habitId: UUID
    public let currentStreak: Int
    public let bestStreak: Int
    public let totalCompletions: Int
    public let completionRate30Days: Double

    public init(habitId: UUID, currentStreak: Int, bestStreak: Int, totalCompletions: Int, completionRate30Days: Double) {
        self.habitId = habitId
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.totalCompletions = totalCompletions
        self.completionRate30Days = completionRate30Days
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    var hexFormat: String {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return "#FFFFFF" }

        let red = Int(round(rgbColor.redComponent * 0xFF))
        let green = Int(round(rgbColor.greenComponent * 0xFF))
        let blue = Int(round(rgbColor.blueComponent * 0xFF))
        let alpha = Int(round(rgbColor.alphaComponent * 0xFF))

        if alpha == 0xFF {
            return String(format: "#%02X%02X%02X", red, green, blue)
        } else {
            return String(format: "#%02X%02X%02X%02X", alpha, red, green, blue)
        }
    }
}
