import XCTest
@testable import boringNotch

// MARK: - Test Doubles

@MainActor
final class MockHoverZoneChecker: HoverZoneChecking {
    var mouseInZone: Bool = false
    var isNotchOpen: Bool = false
    func updateHoverZone(screenUUID: String?) {}
    func isMouseInHoverZone() -> Bool { mouseInZone }
}

struct MockNotchViewModelSettings: NotchViewModelSettings {
    var shelfHoverDelay: Double = 4.0
    var backgroundImageURL: URL?
    var hideNotchOption: HideNotchOption = .never
    var showNotHumanFace: Bool = false
    var hideTitleBar: Bool = false
    var openNotchOnHover: Bool = true
    var openShelfByDefault: Bool = false
    var musicLiveActivityEnabled: Bool = true
    var showPowerStatusNotifications: Bool = true
}

// MARK: - Tests

@MainActor
final class NotchHoverControllerTests: XCTestCase {

    private var hoverChecker: MockHoverZoneChecker!
    private var controller: NotchHoverController!

    override func setUp() {
        super.setUp()
        hoverChecker = MockHoverZoneChecker()
        controller = NotchHoverController(
            settings: MockNotchViewModelSettings(),
            displaySettings: MockNotchSettings(),
            hoverZoneManager: hoverChecker
        )
    }

    // MARK: - State Machine: outside → entering → inside

    func testQuickPassthrough_doesNotOpen() {
        var openCalled = false
        controller.onShouldOpen = { openCalled = true }

        let t0 = Date()

        // Mouse enters
        hoverChecker.mouseInZone = true
        controller.tick(now: t0)
        XCTAssertEqual(controller.state, .entering(since: t0))

        // Mouse leaves at 30ms — before 50ms enter delay
        hoverChecker.mouseInZone = false
        controller.tick(now: t0.addingTimeInterval(0.030))
        XCTAssertEqual(controller.state, .outside)

        // Tick again past the enter delay — should NOT open
        controller.tick(now: t0.addingTimeInterval(0.060))
        XCTAssertFalse(openCalled)
    }

    func testDwell50ms_opens() {
        var openCalled = false
        controller.onShouldOpen = { openCalled = true }

        let t0 = Date()

        hoverChecker.mouseInZone = true
        controller.tick(now: t0)
        XCTAssertEqual(controller.state, .entering(since: t0))

        // Tick just past 50ms — should transition to inside and fire open
        controller.tick(now: t0.addingTimeInterval(0.051))
        XCTAssertEqual(controller.state, .inside)
        XCTAssertTrue(openCalled)
    }

    // MARK: - State Machine: inside → exiting → outside

    func testExitAndClose() {
        var closeCalled = false
        controller.onShouldClose = { closeCalled = true }

        let t0 = Date()

        // Get to .inside state
        hoverChecker.mouseInZone = true
        controller.tick(now: t0)
        controller.tick(now: t0.addingTimeInterval(0.051))
        XCTAssertEqual(controller.state, .inside)

        // Mouse leaves
        hoverChecker.mouseInZone = false
        let exitTime = t0.addingTimeInterval(0.100)
        controller.tick(now: exitTime)
        XCTAssertEqual(controller.state, .exiting(since: exitTime))

        // Not yet past 500ms exit delay
        controller.tick(now: exitTime.addingTimeInterval(0.400))
        XCTAssertFalse(closeCalled)

        // Past 500ms — should close
        controller.tick(now: exitTime.addingTimeInterval(0.500))
        XCTAssertEqual(controller.state, .outside)
        XCTAssertTrue(closeCalled)
    }

    // MARK: - Cancel close: re-enter during exit delay

    func testReenterDuringExitDelay_cancelsClose() {
        var closeCalled = false
        controller.onShouldClose = { closeCalled = true }

        let t0 = Date()

        // Get to .inside
        hoverChecker.mouseInZone = true
        controller.tick(now: t0)
        controller.tick(now: t0.addingTimeInterval(0.051))

        // Mouse leaves
        hoverChecker.mouseInZone = false
        controller.tick(now: t0.addingTimeInterval(0.100))
        XCTAssertEqual(controller.state, .exiting(since: t0.addingTimeInterval(0.100)))

        // Mouse returns at 300ms — within 500ms exit delay
        hoverChecker.mouseInZone = true
        controller.tick(now: t0.addingTimeInterval(0.300))
        XCTAssertEqual(controller.state, .inside)

        // Tick well past original exit time — should NOT close
        controller.tick(now: t0.addingTimeInterval(1.0))
        XCTAssertFalse(closeCalled)
    }

    // MARK: - Shelf mode: 4s exit delay

    func testShelfMode_usesLongerExitDelay() {
        var closeCalled = false
        controller.onShouldClose = { closeCalled = true }
        controller.isShelfActive = { true }

        let t0 = Date()

        // Get to .inside
        hoverChecker.mouseInZone = true
        controller.tick(now: t0)
        controller.tick(now: t0.addingTimeInterval(0.051))

        // Mouse leaves
        hoverChecker.mouseInZone = false
        let exitTime = t0.addingTimeInterval(0.100)
        controller.tick(now: exitTime)

        // At 2s — should NOT close yet (shelf delay is 4s)
        controller.tick(now: exitTime.addingTimeInterval(2.0))
        XCTAssertFalse(closeCalled)

        // Mouse returns at 3s — within 4s shelf delay
        hoverChecker.mouseInZone = true
        controller.tick(now: exitTime.addingTimeInterval(3.0))
        XCTAssertEqual(controller.state, .inside)
        XCTAssertFalse(closeCalled)
    }

    // MARK: - Prevent close

    func testPreventClose_staysInside() {
        controller.shouldPreventClose = { true }

        let t0 = Date()

        // Get to .inside
        hoverChecker.mouseInZone = true
        controller.tick(now: t0)
        controller.tick(now: t0.addingTimeInterval(0.051))
        XCTAssertEqual(controller.state, .inside)

        // Mouse leaves — but close is prevented
        hoverChecker.mouseInZone = false
        controller.tick(now: t0.addingTimeInterval(0.100))
        XCTAssertEqual(controller.state, .inside)
    }

    func testBatteryPopoverActive_staysInside() {
        controller.isBatteryPopoverActive = true

        let t0 = Date()

        // Get to .inside
        hoverChecker.mouseInZone = true
        controller.tick(now: t0)
        controller.tick(now: t0.addingTimeInterval(0.051))

        // Mouse leaves — battery popover blocks exit
        hoverChecker.mouseInZone = false
        controller.tick(now: t0.addingTimeInterval(0.100))
        XCTAssertEqual(controller.state, .inside)
    }

    // MARK: - cancelPendingClose / cancelPendingOpen

    func testCancelPendingClose_transitionsToInside() {
        let t0 = Date()

        // Get to .exiting
        hoverChecker.mouseInZone = true
        controller.tick(now: t0)
        controller.tick(now: t0.addingTimeInterval(0.051))
        hoverChecker.mouseInZone = false
        controller.tick(now: t0.addingTimeInterval(0.100))
        XCTAssertEqual(controller.state, .exiting(since: t0.addingTimeInterval(0.100)))

        controller.cancelPendingClose()
        XCTAssertEqual(controller.state, .inside)
    }

    func testCancelPendingOpen_transitionsToOutside() {
        let t0 = Date()

        hoverChecker.mouseInZone = true
        controller.tick(now: t0)
        XCTAssertEqual(controller.state, .entering(since: t0))

        controller.cancelPendingOpen()
        XCTAssertEqual(controller.state, .outside)
    }

    // MARK: - stopHeartbeat resets state

    func testStopHeartbeat_resetsToOutside() {
        let t0 = Date()

        hoverChecker.mouseInZone = true
        controller.tick(now: t0)
        controller.tick(now: t0.addingTimeInterval(0.051))
        XCTAssertEqual(controller.state, .inside)

        controller.stopHeartbeat()
        XCTAssertEqual(controller.state, .outside)
    }
}
