//
//  HabitStore.swift
//  boringNotch
//
//  Manager for persisting and retrieving habit data.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class HabitStore {
    var habits: [Habit] = []
    var completions: [HabitCompletion] = []
    
    private let fileURL: URL
    
    // Predefined colors for UI
    static let predefinedColors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink, .gray, .white
    ]
    
    // Predefined symbols for UI
    static let predefinedSymbols: [String] = [
        "circle.fill", "star.fill", "heart.fill", "flame.fill", 
        "drop.fill", "bolt.fill", "book.fill", "figure.walk",
        "keyboard", "cup.and.saucer.fill", "apple.logo"
    ]
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("boringNotch")
        
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        self.fileURL = appDir.appendingPathComponent("habits.json")
        load()
        
        // Setup initial default habits if empty
        if habits.isEmpty {
            createDefaultHabits()
        }
    }
    
    // MARK: - Persistence
    
    private struct StorageStruct: Codable {
        var habits: [Habit]
        var completions: [HabitCompletion]
    }
    
    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let storage = try JSONDecoder().decode(StorageStruct.self, from: data)
            self.habits = storage.habits
            self.completions = storage.completions
        } catch {
            print("Failed to load habits: \(error.localizedDescription)")
        }
    }
    
    func save() {
        do {
            let storage = StorageStruct(habits: habits, completions: completions)
            let data = try JSONEncoder().encode(storage)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save habits: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Core Functions
    
    func addHabit(_ habit: Habit) {
        habits.append(habit)
        save()
    }
    
    func updateHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
            save()
        }
    }
    
    func deleteHabit(id: UUID) {
        habits.removeAll { $0.id == id }
        completions.removeAll { $0.habitId == id }
        save()
    }
    
    func toggleCompletion(for habitId: UUID, on date: Date = Date()) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        
        if let existingIndex = completions.firstIndex(where: { $0.habitId == habitId && $0.date == startOfDay }) {
            // Already completed, so un-complete
            completions.remove(at: existingIndex)
        } else {
            // Not completed, so complete
            completions.append(HabitCompletion(habitId: habitId, date: startOfDay))
        }
        
        save()
    }
    
    func isCompleted(habitId: UUID, on date: Date = Date()) -> Bool {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return completions.contains { $0.habitId == habitId && $0.date == startOfDay }
    }
    
    // MARK: - Initial Defaults
    
    private func createDefaultHabits() {
        let defaults = [
            Habit(title: "Drink Water", symbol: "drop.fill", colorHex: Color.blue.hexFormat),
            Habit(title: "Read", symbol: "book.fill", colorHex: Color.purple.hexFormat),
            Habit(title: "Exercise", symbol: "figure.walk", colorHex: Color.orange.hexFormat)
        ]
        
        habits.append(contentsOf: defaults)
        save()
    }
    
    // MARK: - Stats Calculation
    
    func stats(for habitId: UUID) -> HabitStats {
        let habitCompletions = completions
            .filter { $0.habitId == habitId }
            .map { $0.date }
            .sorted(by: >) // newest first
        
        let totalCompletions = habitCompletions.count
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var currentStreak = 0
        var bestStreak = 0
        var tempStreak = 0
        
        // Calculate streaks
        let startOfDays = Set(habitCompletions)
        
        if totalCompletions > 0 {
            // Start checking from today or yesterday
            var checkDate = today
            if !startOfDays.contains(today) {
                checkDate = calendar.date(byAdding: .day, value: -1, to: today)!
            }
            
            // Current streak
            while startOfDays.contains(checkDate) {
                currentStreak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            }
            
            // Best streak (O(n) approach using sorted array)
            if !habitCompletions.isEmpty {
                var previousDate = habitCompletions.last!
                tempStreak = 1
                bestStreak = 1
                
                for i in stride(from: habitCompletions.count - 2, through: 0, by: -1) {
                    let date = habitCompletions[i]
                    let daysBetween = calendar.dateComponents([.day], from: previousDate, to: date).day ?? 0
                    
                    if daysBetween == 1 {
                        tempStreak += 1
                        bestStreak = max(bestStreak, tempStreak)
                    } else if daysBetween > 1 {
                        tempStreak = 1
                    }
                    previousDate = date
                }
            }
        }
        
        // 30 day completion rate
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        let completionsLast30Days = habitCompletions.filter { $0 >= thirtyDaysAgo }.count
        let completionRate30Days = Double(completionsLast30Days) / 30.0
        
        return HabitStats(
            habitId: habitId,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            totalCompletions: totalCompletions,
            completionRate30Days: completionRate30Days
        )
    }
}
