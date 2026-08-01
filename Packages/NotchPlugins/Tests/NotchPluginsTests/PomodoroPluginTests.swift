import XCTest
import NotchCore
@testable import NotchPlugins

@MainActor
final class PomodoroTimerTests: XCTestCase {

    private func makeTimer(workSecs: TimeInterval = 10, shortBreakSecs: TimeInterval = 5, longBreakSecs: TimeInterval = 15, sessionsUntilLong: Int = 4) -> PomodoroTimer {
        let timer = PomodoroTimer()
        timer.updateSettings(PomodoroSettings(
            workDuration: workSecs,
            shortBreakDuration: shortBreakSecs,
            longBreakDuration: longBreakSecs,
            sessionsUntilLongBreak: sessionsUntilLong
        ))
        return timer
    }

    // MARK: - Initial state

    func testInitialStateIsWork() {
        let timer = makeTimer()
        XCTAssertEqual(timer.currentType, .work)
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.completedWorkSessions, 0)
    }

    func testInitialProgressIsZero() {
        let timer = makeTimer(workSecs: 10)
        XCTAssertEqual(timer.progress, 0, accuracy: 0.001)
    }

    func testTimeRemainingStringFormat() {
        let timer = makeTimer(workSecs: 150)
        XCTAssertEqual(timer.timeRemainingString, "02:30")
    }

    // MARK: - Start / Stop

    func testStartSetsIsRunning() {
        let timer = makeTimer()
        timer.start()
        XCTAssertTrue(timer.isRunning)
        timer.stop()
    }

    func testStopClearsIsRunning() {
        let timer = makeTimer()
        timer.start()
        timer.stop()
        XCTAssertFalse(timer.isRunning)
    }

    func testStartIsIdempotentWhenAlreadyRunning() {
        let timer = makeTimer()
        timer.start()
        let taskBefore = timer.isRunning
        timer.start()
        XCTAssertTrue(taskBefore)
        XCTAssertTrue(timer.isRunning)
        timer.stop()
    }

    // MARK: - Reset

    func testResetRestoresTimeRemaining() {
        let timer = makeTimer(workSecs: 25 * 60)
        timer.start()
        timer.stop()
        timer.reset()
        XCTAssertEqual(timer.timeRemainingString, "25:00")
        XCTAssertFalse(timer.isRunning)
    }

    // MARK: - Skip (session completion)

    func testSkipWorkAdvancesToShortBreak() {
        let timer = makeTimer(workSecs: 10, shortBreakSecs: 5, sessionsUntilLong: 4)
        XCTAssertEqual(timer.currentType, .work)
        timer.skip()
        XCTAssertEqual(timer.currentType, .shortBreak)
        XCTAssertEqual(timer.completedWorkSessions, 1)
    }

    func testSkipBreakReturnsToWork() {
        let timer = makeTimer()
        timer.skip() // work → shortBreak
        timer.skip() // shortBreak → work
        XCTAssertEqual(timer.currentType, .work)
    }

    func testSkipFourthWorkSessionAdvancesToLongBreak() {
        let timer = makeTimer(sessionsUntilLong: 4)
        timer.skip() // 1st work → shortBreak
        timer.skip() // shortBreak → work
        timer.skip() // 2nd work → shortBreak
        timer.skip() // shortBreak → work
        timer.skip() // 3rd work → shortBreak
        timer.skip() // shortBreak → work
        timer.skip() // 4th work → longBreak
        XCTAssertEqual(timer.currentType, .longBreak)
        XCTAssertEqual(timer.completedWorkSessions, 0) // resets after long break cycle
    }

    func testSkipLongBreakReturnsToWork() {
        let timer = makeTimer(sessionsUntilLong: 1)
        timer.skip() // work → longBreak (1 session cycle)
        timer.skip() // longBreak → work
        XCTAssertEqual(timer.currentType, .work)
    }

    // MARK: - Session recording

    func testSkipRecordsSession() {
        let timer = makeTimer()
        XCTAssertTrue(timer.completedSessions.isEmpty)
        timer.skip()
        XCTAssertEqual(timer.completedSessions.count, 1)
        XCTAssertEqual(timer.completedSessions.first?.type, .work)
    }

    // MARK: - Plugin metadata

    func testPomodoroPluginMetadata() async throws {
        let plugin = PomodoroPlugin()
        XCTAssertEqual(plugin.id, PluginID.pomodoro)
        XCTAssertFalse(plugin.metadata.name.isEmpty)
        XCTAssertFalse(plugin.metadata.icon.isEmpty)
    }
}
