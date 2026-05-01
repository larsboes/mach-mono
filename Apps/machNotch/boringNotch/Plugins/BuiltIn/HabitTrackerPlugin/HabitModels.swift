//
//  HabitModels.swift
//  boringNotch
//
//  Data models for the Habit Tracker plugin.
//

import Foundation
import SwiftUI

/// Defines a single habit to be tracked.
struct Habit: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var symbol: String
    var colorHex: String
    var createdAt: Date
    var isActive: Bool
    
    // Legacy support or specific days of week could be added here
    var targetDaysPerWeek: Int?
    
    init(id: UUID = UUID(), title: String, symbol: String = "circle.fill", colorHex: String = "#FFFFFF", createdAt: Date = Date(), isActive: Bool = true, targetDaysPerWeek: Int? = nil) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.isActive = isActive
        self.targetDaysPerWeek = targetDaysPerWeek
    }
    
    var color: Color {
        Color(hex: colorHex)
    }
}

/// A record of a habit being completed on a specific date.
struct HabitCompletion: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var habitId: UUID
    var date: Date // Canonicalized to start of day
    var completedAt: Date
    
    init(id: UUID = UUID(), habitId: UUID, date: Date, completedAt: Date = Date()) {
        self.id = id
        self.habitId = habitId
        self.date = Calendar.current.startOfDay(for: date)
        self.completedAt = completedAt
    }
}

/// Aggregated stats for a habit.
struct HabitStats {
    let habitId: UUID
    let currentStreak: Int
    let bestStreak: Int
    let totalCompletions: Int
    let completionRate30Days: Double
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
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
