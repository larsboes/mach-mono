import NotchCore
import NotchServices
import XCTest

@testable import NotchPlugins

@MainActor
final class PluginCoexistenceTests: XCTestCase {

    // MARK: - Declarations

    func testVorssaintOverlapsAreDeclaredOnExactlyTheExpectedPlugins() {
        let declared = PluginRegistry.makeBuiltInDescriptors()
            .filter { $0.coexistence?.app == KnownExternalApp.vorssaint }
            .map(\.id)
            .sorted()

        XCTAssertEqual(
            declared,
            [
                PluginID.clipboard,
                PluginID.shelf,
                PluginID.systemStats,
                PluginID.webcam,
            ].sorted()
        )
    }

    func testBatteryIsNotDeclaredRedundant() {
        let battery = PluginRegistry.makeBuiltInDescriptors().first { $0.id == PluginID.battery }
        XCTAssertNil(battery?.coexistence)
    }

    func testVorssaintBundleIdentifierMatchesTheShippedSignature() {
        // Verified against `codesign -dv` on Vorssaint 3.3.2 and the Homebrew
        // cask's `uninstall quit:` key.
        XCTAssertEqual(KnownExternalApp.vorssaint.bundleIdentifier, "com.vorssaint.utils")
    }

    // MARK: - Resolution

    func testSummaryReportsNoRedundancyWhenTheAppIsAbsent() {
        let manager = makeManager(detector: StubExternalAppDetector())

        let summary = manager.summary(id: PluginID.shelf)

        XCTAssertNotNil(summary?.coexistence)
        XCTAssertFalse(summary?.isRedundant ?? true)
        XCTAssertNil(summary?.coexistence?.summaryText)
        XCTAssertFalse(summary?.coexistence?.offersDisable ?? true)
    }

    func testSummaryReportsRedundancyWhenTheAppIsInstalled() {
        let manager = makeManager(detector: detectorWithVorssaint(.installed(Self.bundleURL)))

        let summary = manager.summary(id: PluginID.shelf)

        XCTAssertTrue(summary?.isRedundant ?? false)
        XCTAssertTrue(summary?.coexistence?.offersDisable ?? false)
        XCTAssertEqual(
            summary?.coexistence?.summaryText,
            "Vorssaint already provides a shelf for files, text and links."
        )
    }

    func testPluginWithoutDeclarationHasNoCoexistence() {
        let manager = makeManager(detector: detectorWithVorssaint(.running(Self.bundleURL)))

        XCTAssertNil(manager.summary(id: PluginID.teleprompter)?.coexistence)
        XCTAssertFalse(manager.summary(id: PluginID.teleprompter)?.isRedundant ?? true)
    }

    func testRedundantSummariesListsOnlyEnabledOverlappingPlugins() async {
        let manager = makeManager(detector: detectorWithVorssaint(.running(Self.bundleURL)))

        await manager.disablePlugin(PluginID.clipboard)

        let redundant = manager.redundantPluginSummaries.map(\.id).sorted()
        XCTAssertEqual(
            redundant,
            [PluginID.shelf, PluginID.systemStats, PluginID.webcam].sorted()
        )
    }

    // MARK: - No Silent State Changes

    func testDetectionNeverDisablesAPluginOnItsOwn() {
        let manager = makeManager(detector: detectorWithVorssaint(.running(Self.bundleURL)))

        _ = manager.allPluginSummaries

        XCTAssertTrue(manager.isPluginEnabled(id: PluginID.shelf))
        XCTAssertTrue(manager.isPluginEnabled(id: PluginID.clipboard))
    }

    // MARK: - Laziness

    func testResolvingCoexistenceDoesNotConstructPlugins() {
        let manager = makeManager(detector: detectorWithVorssaint(.installed(Self.bundleURL)))

        _ = manager.allPluginSummaries
        _ = manager.redundantPluginSummaries

        XCTAssertTrue(manager.allPlugins.isEmpty)
    }

    func testRefreshForwardsToTheDetector() {
        let detector = detectorWithVorssaint(.installed(Self.bundleURL))
        let manager = makeManager(detector: detector)

        manager.refreshExternalApps()

        XCTAssertEqual(detector.refreshCount, 1)
    }

    // MARK: - Detector Contract

    func testStubReturnsAbsentForUnknownBundleIdentifiers() {
        let detector = StubExternalAppDetector()
        XCTAssertEqual(detector.presence(of: KnownExternalApp.vorssaint), .absent)
    }

    func testRunningPresenceImpliesInstalled() {
        XCTAssertTrue(ExternalAppPresence.running(Self.bundleURL).isInstalled)
        XCTAssertTrue(ExternalAppPresence.running(Self.bundleURL).isRunning)
        XCTAssertTrue(ExternalAppPresence.installed(Self.bundleURL).isInstalled)
        XCTAssertFalse(ExternalAppPresence.installed(Self.bundleURL).isRunning)
        XCTAssertFalse(ExternalAppPresence.absent.isInstalled)
    }

    // MARK: - Helpers

    private static let bundleURL = URL(fileURLWithPath: "/Applications/Vorssaint.app")

    private func detectorWithVorssaint(_ presence: ExternalAppPresence) -> StubExternalAppDetector {
        StubExternalAppDetector(presences: [KnownExternalApp.vorssaint.bundleIdentifier: presence])
    }

    private func makeManager(detector: any ExternalAppDetecting) -> PluginManager {
        PluginManager(
            services: TestNotchServiceProvider(music: MockMusicService()),
            eventBus: PluginEventBus(),
            appState: MockAppState(),
            mediaSettings: MockNotchSettings(),
            coordinator: CoexistenceTestCoordinator(),
            builtInDescriptors: PluginRegistry.makeBuiltInDescriptors(),
            externalApps: detector
        )
    }
}

@MainActor
private final class CoexistenceTestCoordinator: NotchAnimationStateProviding {
    var helloAnimationRunning = false
    var sneakPeek = SneakPeekState(show: false, type: .music, value: 0, icon: "")
    var expandingView = ExpandedItem(show: false, type: .battery, value: 0)
    var shelfService: (any ShelfServiceProtocol)?
}
