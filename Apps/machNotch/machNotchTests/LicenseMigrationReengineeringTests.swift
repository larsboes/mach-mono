//
//  LicenseMigrationReengineeringTests.swift
//  machNotchTests
//
//  Tests for reauthored MIT-migration code paths.
//

import Combine
import XCTest

@testable import machNotch

@MainActor
final class LicenseMigrationReengineeringTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testNotchGeometryDerivesPhysicalWidthFromAuxiliaryAreas() {
        let metrics = NotchGeometry.ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 944),
            safeAreaTop: 38,
            auxiliaryTopLeftWidth: 634,
            auxiliaryTopRightWidth: 634
        )

        XCTAssertEqual(NotchGeometry.physicalNotchWidth(metrics: metrics), 256)
    }

    func testNotchGeometryUsesLiveActivityHeightPolicy() {
        let settings = MockNotchSettings()
        settings.notchHeightMode = .custom
        settings.notchHeight = 44
        settings.nonNotchHeightMode = .custom
        settings.nonNotchHeight = 26

        let notched = NotchGeometry.ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 944),
            safeAreaTop: 38
        )
        let plain = NotchGeometry.ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875),
            safeAreaTop: 0
        )

        XCTAssertEqual(
            NotchGeometry.closedHeight(settings: settings, metrics: notched, hasLiveActivity: false),
            38
        )
        XCTAssertEqual(
            NotchGeometry.closedHeight(settings: settings, metrics: notched, hasLiveActivity: true),
            44
        )
        XCTAssertEqual(
            NotchGeometry.closedHeight(settings: settings, metrics: plain, hasLiveActivity: false),
            26
        )
        XCTAssertEqual(
            NotchGeometry.closedHeight(settings: settings, metrics: plain, hasLiveActivity: true),
            NotchGeometry.fallbackNonNotchLiveHeight
        )
    }

    func testFullscreenPolicyFiltersNowPlayingWhenRequested() {
        let spaces = [
            FullscreenSpaceSnapshot(runningApps: ["com.apple.Music"], screenUUID: "built-in"),
            FullscreenSpaceSnapshot(runningApps: ["com.apple.Safari"], screenUUID: "external"),
            FullscreenSpaceSnapshot(runningApps: ["com.apple.TV"], screenUUID: nil),
        ]

        let statuses = FullscreenMediaDetectionPolicy.statusByScreen(
            spaces: spaces,
            hideOption: .nowPlayingOnly,
            nowPlayingBundleIdentifier: "com.apple.Music"
        )

        XCTAssertEqual(statuses, ["built-in": true, "external": false])
    }

    func testMediaKeyRouterAppliesFineVolumeStep() {
        let services = MediaKeyRouterSpies()
        let settings = MockNotchSettings()
        let router = MediaKeyActionRouter(
            volumeService: services.volume,
            brightnessService: services.brightness,
            keyboardBacklightService: services.backlight,
            eventBus: PluginEventBus(),
            settings: settings,
            playFeedbackSound: { services.feedbackCount += 1 }
        )

        router.handle(
            MediaKeyPress(kind: .soundUp, modifiers: MediaKeyModifiers(option: true, shift: true))
        )

        XCTAssertEqual(services.volume.increaseDivisors, [4])
        XCTAssertEqual(services.feedbackCount, 1)
    }

    func testMediaKeyRouterEmitsBacklightHUDForCommandBrightness() {
        let services = MediaKeyRouterSpies()
        let settings = MockNotchSettings()
        settings.optionKeyAction = .showHUD
        services.backlight.rawBrightness = 0.75

        var emitted: SneakPeekRequest?
        let bus = PluginEventBus()
        bus.subscribe(to: SneakPeekRequestedEvent.self) { event in
            emitted = event.request
        }
        .store(in: &cancellables)

        let router = MediaKeyActionRouter(
            volumeService: services.volume,
            brightnessService: services.brightness,
            keyboardBacklightService: services.backlight,
            eventBus: bus,
            settings: settings,
            playFeedbackSound: {}
        )

        router.handle(
            MediaKeyPress(kind: .brightnessUp, modifiers: MediaKeyModifiers(option: true, command: true))
        )

        XCTAssertEqual(emitted?.type, .backlight)
        XCTAssertEqual(emitted?.value, 0.75)
    }
}

@MainActor
private final class MediaKeyRouterSpies {
    let volume = SpyVolumeService()
    let brightness = SpyBrightnessService()
    let backlight = SpyKeyboardBacklightService()
    var feedbackCount = 0
}

@MainActor
@Observable
private final class SpyVolumeService: VolumeServiceProtocol {
    var rawVolume: Float = 0.5
    var isMuted: Bool = false
    var increaseDivisors: [Float] = []
    var decreaseDivisors: [Float] = []
    var toggleMuteCount = 0

    func increase(stepDivisor: Float) { increaseDivisors.append(stepDivisor) }
    func decrease(stepDivisor: Float) { decreaseDivisors.append(stepDivisor) }
    func toggleMuteAction() { toggleMuteCount += 1 }
    func setAbsolute(_ value: Float) { rawVolume = value }
    func refresh() {}
}

@MainActor
@Observable
private final class SpyBrightnessService: BrightnessServiceProtocol {
    var rawBrightness: Float = 0.5
    var relativeDeltas: [Float] = []

    func setRelative(delta: Float) { relativeDeltas.append(delta) }
    func setAbsolute(value: Float) { rawBrightness = value }
    func refresh() {}
}

@MainActor
@Observable
private final class SpyKeyboardBacklightService: KeyboardBacklightServiceProtocol {
    var rawBrightness: Float = 0.5
    var relativeDeltas: [Float] = []

    func setRelative(delta: Float) { relativeDeltas.append(delta) }
    func setAbsolute(value: Float) { rawBrightness = value }
    func refresh() {}
}
