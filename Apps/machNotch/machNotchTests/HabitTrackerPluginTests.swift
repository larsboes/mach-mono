//
//  HabitTrackerPluginTests.swift
//  machNotchTests
//

import XCTest
@testable import machNotch

@MainActor
final class HabitStoreTests: XCTestCase {

    private func makeStore() -> HabitStore {
        let store = HabitStore()
        // Clear default habits so tests start empty
        for habit in store.habits {
            store.deleteHabit(id: habit.id)
        }
        return store
    }

    private func makeHabit(title: String = "Test") -> Habit {
        Habit(title: title, symbol: "circle.fill", colorHex: "#FF0000")
    }

    // MARK: - CRUD

    func testAddHabitAppendsToList() {
        let store = makeStore()
        store.addHabit(makeHabit(title: "Run"))
        XCTAssertEqual(store.habits.count, 1)
        XCTAssertEqual(store.habits.first?.title, "Run")
    }

    func testDeleteHabitRemovesFromList() {
        let store = makeStore()
        let habit = makeHabit()
        store.addHabit(habit)
        store.deleteHabit(id: habit.id)
        XCTAssertTrue(store.habits.isEmpty)
    }

    func testUpdateHabitMutatesTitle() {
        let store = makeStore()
        var habit = makeHabit(title: "Old")
        store.addHabit(habit)
        habit.title = "New"
        store.updateHabit(habit)
        XCTAssertEqual(store.habits.first?.title, "New")
    }

    func testDeleteHabitAlsoClearsCompletions() {
        let store = makeStore()
        let habit = makeHabit()
        store.addHabit(habit)
        store.toggleCompletion(for: habit.id)
        XCTAssertTrue(store.isCompleted(habitId: habit.id))
        store.deleteHabit(id: habit.id)
        // completions array is also cleared
        XCTAssertTrue(store.completions.isEmpty)
    }

    // MARK: - Toggle completion

    func testToggleMarksDayComplete() {
        let store = makeStore()
        let habit = makeHabit()
        store.addHabit(habit)
        store.toggleCompletion(for: habit.id)
        XCTAssertTrue(store.isCompleted(habitId: habit.id))
    }

    func testToggleTwiceUndoesCompletion() {
        let store = makeStore()
        let habit = makeHabit()
        store.addHabit(habit)
        store.toggleCompletion(for: habit.id)
        store.toggleCompletion(for: habit.id)
        XCTAssertFalse(store.isCompleted(habitId: habit.id))
    }

    func testCompletionIsDateIsolated() {
        let store = makeStore()
        let habit = makeHabit()
        store.addHabit(habit)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        store.toggleCompletion(for: habit.id, on: yesterday)
        XCTAssertFalse(store.isCompleted(habitId: habit.id)) // today still false
        XCTAssertTrue(store.isCompleted(habitId: habit.id, on: yesterday))
    }

    // MARK: - Stats: streak

    func testNoCompletionsGivesZeroStreak() {
        let store = makeStore()
        let habit = makeHabit()
        store.addHabit(habit)
        let stats = store.stats(for: habit.id)
        XCTAssertEqual(stats.currentStreak, 0)
        XCTAssertEqual(stats.bestStreak, 0)
        XCTAssertEqual(stats.totalCompletions, 0)
    }

    func testSingleTodayCompletionGivesStreakOfOne() {
        let store = makeStore()
        let habit = makeHabit()
        store.addHabit(habit)
        store.toggleCompletion(for: habit.id)
        let stats = store.stats(for: habit.id)
        XCTAssertEqual(stats.currentStreak, 1)
    }

    func testConsecutiveDaysBuildsStreak() {
        let store = makeStore()
        let habit = makeHabit()
        store.addHabit(habit)
        let today = Date()
        for daysBack in 0..<5 {
            let date = Calendar.current.date(byAdding: .day, value: -daysBack, to: today)!
            store.toggleCompletion(for: habit.id, on: date)
        }
        let stats = store.stats(for: habit.id)
        XCTAssertEqual(stats.currentStreak, 5)
    }

    func testGapBreaksCurrentStreak() {
        let store = makeStore()
        let habit = makeHabit()
        store.addHabit(habit)
        // Complete today and 3 days ago (gap on days 1 and 2)
        store.toggleCompletion(for: habit.id, on: Date())
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        store.toggleCompletion(for: habit.id, on: threeDaysAgo)
        let stats = store.stats(for: habit.id)
        XCTAssertEqual(stats.currentStreak, 1) // only today counts
    }

    // MARK: - Stats: completion rate

    func testCompletionRateIsProportional() {
        let store = makeStore()
        let habit = makeHabit()
        store.addHabit(habit)
        // Complete 15 of last 30 days
        let today = Date()
        for i in 0..<15 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
            store.toggleCompletion(for: habit.id, on: date)
        }
        let stats = store.stats(for: habit.id)
        XCTAssertEqual(stats.completionRate30Days, 0.5, accuracy: 0.01)
    }

    // MARK: - Plugin metadata

    func testHabitTrackerPluginMetadata() {
        let plugin = HabitTrackerPlugin()
        XCTAssertEqual(plugin.id, PluginID.habitTracker)
        XCTAssertFalse(plugin.metadata.name.isEmpty)
    }
}
