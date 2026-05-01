//
//  NotchStateMachineTests.swift
//  boringNotchTests
//
//  Unit tests for NotchStateMachine.
//  Tests state computation logic extracted from ContentView.
//

import XCTest
@testable import boringNotch

@MainActor
final class NotchStateMachineTests: XCTestCase {

    // MARK: - Test Fixtures

    /// Creates a default input with all options disabled for isolation testing
    func makeDefaultInput() -> NotchStateInput {
        NotchStateInput(
            notchState: .closed,
            currentView: .home,
            helloAnimationRunning: false,
            sneakPeek: SneakPeekState(show: false, type: .music, value: 0.0, icon: ""),
            expandingView: ExpandedItem(show: false, type: .battery, value: 0),
            activePluginId: nil,
            isPlayerIdle: true,
            isPlaying: false,
            hideOnClosed: false,
            showInlineHUD: false,
            showNotHumanFace: false,
            sneakPeekStyle: .standard
        )
    }

    /// Creates a state machine with mock settings for testing
    func makeStateMachine() -> NotchStateMachine {
        let settings = MockNotchSettings()
        return NotchStateMachine(settings: settings)
    }

    // MARK: - Priority 1: Hello Animation Tests

    func testHelloAnimationTakesPriorityOverEverything() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.helloAnimationRunning = true
        // Enable everything else to ensure hello animation takes priority
        input.notchState = .open
        input.isPlaying = true
        input.activePluginId = "com.boringnotch.music"
        input.sneakPeek = SneakPeekState(show: true, type: .volume, value: 0.5, icon: "speaker")
        
        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .helloAnimation, "Hello animation should have highest priority")
    }

    // MARK: - Priority 2: Open State Tests

    func testOpenStateShowsCurrentView() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .open
        input.currentView = .shelf

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .open(view: .shelf))
    }

    func testOpenStateOverridesPlugin() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .open
        input.activePluginId = "com.boringnotch.music"

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .open(view: .home), "Open state should override plugin")
    }

    // MARK: - Priority 3: Inline HUD Tests

    func testInlineHUDForVolumeChange() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.sneakPeek = SneakPeekState(show: true, type: .volume, value: 0.75, icon: "speaker.wave.3")
        input.showInlineHUD = true

        let state = stateMachine.computeDisplayState(from: input)

        if case .closed(let content) = state {
            if case .inlineHUD(let type, let value, let icon) = content {
                XCTAssertEqual(type, .volume)
                XCTAssertEqual(value, 0.75, accuracy: 0.01)
                XCTAssertEqual(icon, "speaker.wave.3")
            } else {
                XCTFail("Expected inlineHUD content, got \(content)")
            }
        } else {
            XCTFail("Expected closed state")
        }
    }

    // MARK: - Priority 4: Active Plugin Content Tests

    func testMusicPluginActive() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.activePluginId = "com.boringnotch.music"
        input.hideOnClosed = false

        let state = stateMachine.computeDisplayState(from: input)

        if case .closed(let content) = state {
            if case .plugin(let id) = content {
                XCTAssertEqual(id, "com.boringnotch.music")
            } else {
                XCTFail("Expected plugin content")
            }
        } else {
            XCTFail("Expected closed state")
        }
    }

    func testBatteryPluginActive() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.activePluginId = "com.boringnotch.battery"
        
        let state = stateMachine.computeDisplayState(from: input)

        if case .closed(let content) = state {
            if case .plugin(let id) = content {
                XCTAssertEqual(id, "com.boringnotch.battery")
            } else {
                XCTFail("Expected plugin content")
            }
        } else {
            XCTFail("Expected closed state")
        }
    }

    func testPluginNotShownWhenHideOnClosed() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.activePluginId = "com.boringnotch.music"
        input.hideOnClosed = true

        let state = stateMachine.computeDisplayState(from: input)

        // Should fall through to idle or face
        XCTAssertNotEqual(state, .closed(content: .plugin("com.boringnotch.music")))
    }

    // MARK: - Priority 5: Face Animation Tests

    func testFaceAnimationWhenEnabled() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.isPlaying = false
        input.isPlayerIdle = true
        input.showNotHumanFace = true
        input.hideOnClosed = false
        input.activePluginId = nil

        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .closed(content: .face))
    }

    func testFaceAnimationNotShownWhenPluginActive() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.showNotHumanFace = true
        input.activePluginId = "com.boringnotch.music"

        let state = stateMachine.computeDisplayState(from: input)

        // Plugin has higher priority than face
        if case .closed(let content) = state {
            if case .plugin(let id) = content {
                XCTAssertEqual(id, "com.boringnotch.music")
            } else {
                XCTFail("Expected plugin content to override face")
            }
        }
    }

    // MARK: - Priority 6: Standard Sneak Peek Tests

    func testStandardSneakPeekForBrightness() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.sneakPeek = SneakPeekState(show: true, type: .brightness, value: 0.7, icon: "sun.max")
        input.showInlineHUD = false  // Inline HUD disabled

        let state = stateMachine.computeDisplayState(from: input)

        if case .closed(let content) = state {
            if case .sneakPeek(let type, let value, _) = content {
                XCTAssertEqual(type, .brightness)
                XCTAssertEqual(value, 0.7, accuracy: 0.01)
            } else {
                XCTFail("Expected sneakPeek content")
            }
        }
    }

    // MARK: - Priority 7: Music Sneak Peek Tests

    func testMusicSneakPeekWithStandardStyle() {
        let stateMachine = makeStateMachine()

        var input = makeDefaultInput()
        input.notchState = .closed
        input.sneakPeek = SneakPeekState(show: true, type: .music, value: 0, icon: "music.note")
        input.hideOnClosed = false
        input.sneakPeekStyle = .standard
        input.activePluginId = nil // Ensure regular plugin view isn't active

        let state = stateMachine.computeDisplayState(from: input)

        if case .closed(let content) = state {
            if case .sneakPeek(let type, _, _) = content {
                XCTAssertEqual(type, .music)
            } else {
                XCTFail("Expected sneakPeek content for music")
            }
        }
    }

    // MARK: - Default Idle State Tests

    func testClosedIdleStateWhenNothingActive() {
        let stateMachine = makeStateMachine()

        let input = makeDefaultInput()
        let state = stateMachine.computeDisplayState(from: input)

        XCTAssertEqual(state, .closed(content: .idle))
    }

    // MARK: - Chin Width Computation Tests

    func testChinWidthForPlugin() {
        let stateMachine = makeStateMachine()

        stateMachine.transition(to: .closed(content: .plugin("com.boringnotch.music")))

        let baseWidth: CGFloat = 200
        let notchHeight: CGFloat = 32
        let expectedWidth = baseWidth + (2 * max(0, notchHeight - 12) + 20)

        let chinWidth = stateMachine.computeChinWidth(
            baseWidth: baseWidth,
            displayClosedNotchHeight: notchHeight
        )

        XCTAssertEqual(chinWidth, expectedWidth)
    }

    func testChinWidthForIdleState() {
        let stateMachine = makeStateMachine()

        stateMachine.transition(to: .closed(content: .idle))

        let baseWidth: CGFloat = 200
        let chinWidth = stateMachine.computeChinWidth(
            baseWidth: baseWidth,
            displayClosedNotchHeight: 32
        )

        XCTAssertEqual(chinWidth, baseWidth, "Idle state should use base width")
    }
}
