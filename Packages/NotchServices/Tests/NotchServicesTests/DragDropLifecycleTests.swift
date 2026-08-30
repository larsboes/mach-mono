//
//  DragDropLifecycleTests.swift
//  NotchServicesTests
//
//  `DragDropService` installs system-wide mouse monitors while at least one
//  observer is registered. These pin that lifecycle, and the per-observer
//  regions that let one notch window per display coexist.
//

import NotchCore
import XCTest

@testable import NotchServices

@MainActor
final class DragDropLifecycleTests: XCTestCase {

    func testDragDropInstallsNoMonitorsUntilSomebodyObserves() {
        let service = DragDropService()

        // Three system-wide mouse monitors used to be installed at view-model
        // setup and never removed, whether or not the shelf was in use.
        XCTAssertEqual(service.observerCount, 0)
        XCTAssertFalse(service.isMonitoring)
    }

    func testDragDropStopsWhenTheLastObserverLeaves() {
        let service = DragDropService()

        let first = service.addObserver(region: .zero, onEnter: {})
        let second = service.addObserver(region: .zero, onEnter: {})
        XCTAssertEqual(service.observerCount, 2)

        service.removeObserver(first)
        XCTAssertTrue(service.isMonitoring)

        service.removeObserver(second)
        XCTAssertFalse(service.isMonitoring)
    }

    func testRemovingAnUnknownObserverIsIgnored() {
        let service = DragDropService()
        let token = service.addObserver(region: .zero, onEnter: {})

        service.removeObserver(token)
        service.removeObserver(token)

        XCTAssertEqual(service.observerCount, 0)
    }

    func testObserversKeepSeparateRegions() {
        let service = DragDropService()
        let left = CGRect(x: 0, y: 0, width: 100, height: 10)
        let right = CGRect(x: 500, y: 0, width: 100, height: 10)

        // One notch window per display. A single-slot callback meant the second
        // display overwrote the first one's region and handlers.
        let leftToken = service.addObserver(region: left, onEnter: {})
        let rightToken = service.addObserver(region: right, onEnter: {})

        XCTAssertEqual(service.observerCount, 2)
        XCTAssertNotEqual(leftToken, rightToken)

        service.updateRegion(CGRect(x: 0, y: 0, width: 200, height: 20), for: leftToken)
        XCTAssertEqual(service.observerCount, 2)
    }
}
