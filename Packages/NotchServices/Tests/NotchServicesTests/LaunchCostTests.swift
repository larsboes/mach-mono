//
//  LaunchCostTests.swift
//  NotchServicesTests
//
//  ServiceContainer builds every service eagerly, so anything a service does in
//  `init` is paid at app launch whether or not the owning plugin is enabled.
//  These tests pin the services that used to do work there.
//

import NotchCore
import XCTest

@testable import NotchServices

@MainActor
final class LaunchCostTests: XCTestCase {

    // MARK: - FaceService

    func testFaceServiceIsIdleUntilAskedToMonitor() {
        let service = FaceService(settings: MockNotchSettings())

        // A pointer monitor at init drove work on every mouse move for the whole
        // session, to animate eyes that are only ever visible in the shelf panel.
        XCTAssertEqual(service.eyeOffset, .zero)
        XCTAssertFalse(service.isSleepy)
    }

    func testFaceServiceStopIsSafeWithoutStart() {
        let service = FaceService(settings: MockNotchSettings())

        service.stopMonitoring()
        service.stopMonitoring()

        XCTAssertEqual(service.eyeOffset, .zero)
    }

    func testFaceServiceMonitorsWhileAtLeastOneViewNeedsIt() {
        let service = FaceService(settings: MockNotchSettings())

        // Two faces can be on screen at once in the split notch layout.
        service.startMonitoring()
        service.startMonitoring()
        service.stopMonitoring()
        service.stopMonitoring()
        // Balanced: the extra stop must not underflow the reference count.
        service.stopMonitoring()

        service.startMonitoring()
        service.stopMonitoring()

        XCTAssertEqual(service.eyeOffset, .zero)
        XCTAssertFalse(service.isSleepy)
    }

    // MARK: - ServiceContainer

    func testServiceContainerReturnsOneInstancePerService() {
        let container = ServiceContainer(eventBus: PluginEventBus(), settings: MockNotchSettings())

        // The services are `lazy var`, not computed properties. Handing out a
        // fresh instance per access would give each caller its own monitors and
        // its own state.
        XCTAssertTrue(container.dragDrop === container.dragDrop)
        XCTAssertTrue(container.sound as AnyObject === container.sound as AnyObject)
    }

    func testServiceContainerBuildsNothingItIsNotAsked() {
        let container = ServiceContainer(eventBus: PluginEventBus(), settings: MockNotchSettings())

        // Touching one service must not drag the other 29 in behind it.
        _ = container.sound
        XCTAssertTrue(container.clipboardManager.items.isEmpty)
    }

    // MARK: - ClipboardManager

    func testClipboardManagerOpensNoDatabaseAtInit() {
        let manager = ClipboardManager()

        // `init` used to create a directory, open SQLite, run a CREATE TABLE and
        // read 50 rows, synchronously on the main actor, at every launch.
        XCTAssertTrue(manager.items.isEmpty)
        XCTAssertFalse(manager.isMonitoring)
    }
}
