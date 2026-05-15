//
//  HabitStore.swift
//  machNotch
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
    private var saveTask: Task<Void, Never>?

    static let predefinedColors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink, .gray, .white,
    ]

    static let predefinedSymbols: [String] = [
        "circle.fill", "star.fill", "heart.fill", "flame.fill",
        "drop.fill", "bolt.fill", "book.fill", "figure.walk",
        "keyboard", "cup.and.saucer.fill", "apple.logo",
    ]

    init() {
        let appSupport =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let appDir = appSupport.appendingPathComponent("machNotch")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.fileURL = appDir.appendingPathComponent("habits.json")
        load()
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
        let snapshot = StorageStruct(habits: habits, completions: completions)
        let url = fileURL
        saveTask?.cancel()
        saveTask = Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                print("Failed to save habits: \(error.localizedDescription)")
            }
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

    func reorderHabits(from: IndexSet, to: Int) {
        habits.move(fromOffsets: from, toOffset: to)
        save()
    }

    func toggleCompletion(for habitId: UUID, on date: Date = Date()) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        if completions.contains(where: { $0.habitId == habitId && $0.date == startOfDay }) {
            completions.removeAll { $0.habitId == habitId && $0.date == startOfDay }
        } else {
            completions.append(HabitCompletion(habitId: habitId, date: startOfDay))
        }
        save()
    }

    func isCompleted(habitId: UUID, on date: Date = Date()) -> Bool {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return completions.contains { $0.habitId == habitId && $0.date == startOfDay }
    }

    // MARK: - Stats

    func stats(for habitId: UUID) -> HabitStats {
        let habitCompletions =
            completions
            .filter { $0.habitId == habitId }
            .map { $0.date }
            .sorted(by: >)

        let totalCompletions = habitCompletions.count
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var currentStreak = 0
        var bestStreak = 0
        var tempStreak = 0

        let startOfDays = Set(habitCompletions)

        if totalCompletions > 0 {
            var checkDate = today
            if !startOfDays.contains(today) {
                checkDate = calendar.date(byAdding: .day, value: -1, to: today)!
            }
            while startOfDays.contains(checkDate) {
                currentStreak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            }

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

        // Use days-since-creation as denominator for habits newer than 30 days,
        // unless the habit has completions predating its creation date (retroactive entry).
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        let completionsLast30Days = habitCompletions.filter { $0 >= thirtyDaysAgo }.count

        let denominator: Double
        if let createdAt = habits.first(where: { $0.id == habitId })?.createdAt {
            let startOfCreation = calendar.startOfDay(for: createdAt)
            let daysSince = (calendar.dateComponents([.day], from: startOfCreation, to: today).day ?? 0) + 1
            let hasRetroCompletions = habitCompletions.contains { $0 < startOfCreation }
            if daysSince < 30 && !hasRetroCompletions {
                denominator = Double(max(1, daysSince))
            } else {
                denominator = 30
            }
        } else {
            denominator = 30
        }
        let completionRate30Days = Double(completionsLast30Days) / denominator

        return HabitStats(
            habitId: habitId,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            totalCompletions: totalCompletions,
            completionRate30Days: completionRate30Days
        )
    }
}
