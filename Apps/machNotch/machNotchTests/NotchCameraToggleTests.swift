//
//  NotchCameraToggleTests.swift
//  machNotchTests
//

import AVFoundation
import XCTest

@testable import machNotch

@MainActor
final class NotchCameraToggleTests: XCTestCase {

    func testAuthorizedAvailableCameraStartsMirror() {
        let (viewModel, webcam) = makeSUT()
        webcam.authorizationStatus = .authorized
        webcam.cameraAvailable = true

        viewModel.toggleCameraPreview()

        XCTAssertEqual(webcam.startSessionCallCount, 1)
        XCTAssertTrue(viewModel.isCameraExpanded)
    }

    func testAuthorizedRunningCameraStopsMirror() {
        let (viewModel, webcam) = makeSUT()
        webcam.authorizationStatus = .authorized
        webcam.cameraAvailable = true
        webcam.isSessionRunning = true
        viewModel.isCameraExpanded = true

        viewModel.toggleCameraPreview()

        XCTAssertEqual(webcam.stopSessionCallCount, 1)
        XCTAssertFalse(viewModel.isCameraExpanded)
    }

    func testUndeterminedCameraExpandsPermissionTileWithoutRequestingImmediately() {
        let (viewModel, webcam) = makeSUT()
        webcam.authorizationStatus = .notDetermined

        viewModel.toggleCameraPreview()

        XCTAssertTrue(viewModel.isCameraExpanded)
        XCTAssertEqual(webcam.authorizationRequestCallCount, 0)
        XCTAssertEqual(webcam.startSessionCallCount, 0)
    }

    func testDeniedCameraExpandsPermissionTileWithoutStartingSession() {
        let (viewModel, webcam) = makeSUT()
        webcam.authorizationStatus = .denied

        viewModel.toggleCameraPreview()

        XCTAssertTrue(viewModel.isCameraExpanded)
        XCTAssertEqual(webcam.startSessionCallCount, 0)
        XCTAssertEqual(webcam.stopSessionCallCount, 0)
    }

    func testWebcamPluginActivationRefreshesStatusWithoutPrompting() async throws {
        let services = TestNotchServiceProvider(music: MockMusicService())
        let webcam = try XCTUnwrap(services.webcam as? StubWebcamService)
        let plugin = WebcamPlugin()

        let context = PluginContext(
            settings: PluginSettings(pluginId: plugin.id),
            services: services,
            eventBus: PluginEventBus(),
            appState: MockAppState(),
            mediaSettings: MockNotchSettings()
        )

        try await plugin.activate(context: context)

        XCTAssertEqual(webcam.refreshAuthorizationCallCount, 1)
        XCTAssertEqual(webcam.refreshCameraDevicesCallCount, 1)
        XCTAssertEqual(webcam.authorizationRequestCallCount, 0)
    }

    private func makeSUT() -> (NotchViewModel, StubWebcamService) {
        let settings = MockNotchSettings()
        let services = TestNotchServiceProvider(music: MockMusicService())
        let webcam = services.webcam as! StubWebcamService
        let viewModel = NotchViewModel(
            coordinator: NotchViewCoordinator(settings: settings, xpcHelper: services.xpcHelper),
            detector: FullscreenMediaDetector(musicService: services.music, settings: settings),
            services: services,
            displaySettings: settings
        )

        return (viewModel, webcam)
    }
}
