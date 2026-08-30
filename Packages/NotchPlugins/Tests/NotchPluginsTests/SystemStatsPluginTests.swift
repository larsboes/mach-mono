import SwiftUI
import XCTest

import NotchCore
import NotchServices

@testable import NotchPlugins

/// Covers #69: the plugin's sampling configuration and its rendering lifecycle.
///
/// The acceptance that matters is "metrics sampling remains bounded and doesn't
/// cause background UI churn", which is a property of activate/deactivate and
/// of the refresh interval, not of the rings themselves.
@MainActor
final class SystemStatsPluginTests: XCTestCase {

    // PluginSettings writes straight to UserDefaults.standard with no suite
    // seam, so every test gets its own namespace. Sharing one would leak state
    // between tests and, in an app process, would write the user's real keys.
    private var settingsNamespace: String!

    override func setUp() {
        super.setUp()
        settingsNamespace = "test.systemstats.\(UUID().uuidString)"
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            PluginSettings(pluginId: settingsNamespace).removeAll()
        }
        super.tearDown()
    }

    private var settings: PluginSettings {
        PluginSettings(pluginId: settingsNamespace)
    }

    private func activated() async throws -> (SystemStatsPlugin, StubSystemStatsService) {
        let plugin = SystemStatsPlugin()
        let services = TestNotchServiceProvider(music: MockMusicService())
        try await plugin.activate(
            context: PluginContext(
                settings: settings,
                services: services,
                eventBus: PluginEventBus(),
                appState: MockAppState(),
                mediaSettings: MockNotchSettings()
            )
        )
        let stats = try XCTUnwrap(plugin.statsService as? StubSystemStatsService)
        return (plugin, stats)
    }

    // MARK: - Sampling lifecycle

    func testActivateStartsMonitoringExactlyOnce() async throws {
        let (plugin, stats) = try await activated()

        XCTAssertEqual(plugin.state, .active)
        XCTAssertEqual(stats.startCount, 1)
        XCTAssertTrue(stats.isMonitoring)
    }

    func testDeactivateStopsMonitoringAndReleasesTheService() async throws {
        let (plugin, stats) = try await activated()

        await plugin.deactivate()

        XCTAssertEqual(stats.stopCount, 1, "a disabled plugin must not keep sampling")
        XCTAssertFalse(stats.isMonitoring)
        XCTAssertNil(plugin.statsService, "the service reference must not outlive activation")
        XCTAssertEqual(plugin.state, .inactive)
    }

    func testActivateAppliesTheRefreshIntervalToTheService() async throws {
        let (plugin, stats) = try await activated()
        XCTAssertEqual(stats.refreshInterval, plugin.refreshInterval)
    }

    // MARK: - Bounded sampling

    func testRefreshIntervalIsClampedOnWrite() async throws {
        let (plugin, stats) = try await activated()

        plugin.refreshInterval = 900
        XCTAssertEqual(plugin.refreshInterval, 5)
        XCTAssertEqual(stats.refreshInterval, 5)

        plugin.refreshInterval = 0
        XCTAssertEqual(plugin.refreshInterval, 1)
        XCTAssertEqual(stats.refreshInterval, 1)
    }

    func testRefreshIntervalIsClampedOnReadForAStoredOutOfRangeValue() async throws {
        let (plugin, _) = try await activated()

        // What an older build, or a hand-edited defaults entry, could leave behind.
        settings.set("refreshInterval", value: 0.05)

        XCTAssertEqual(
            plugin.refreshInterval, 1,
            "a stored value below the floor must not reach the sampler"
        )
    }

    // MARK: - Rendering lifecycle

    func testNoDisplayRequestBeforeActivation() {
        XCTAssertNil(
            SystemStatsPlugin().displayRequest,
            "an inactive plugin must not compete for the closed notch"
        )
    }

    func testDisplayRequestIsBackgroundPriorityWhenActive() async throws {
        let (plugin, _) = try await activated()

        let request = try XCTUnwrap(plugin.displayRequest)
        XCTAssertEqual(request.priority, .background)
        XCTAssertEqual(request.category, .system)
    }

    func testDisplayRequestDisappearsAfterDeactivation() async throws {
        let (plugin, _) = try await activated()
        await plugin.deactivate()

        XCTAssertNil(plugin.displayRequest)
    }

    func testDisabledPluginMakesNoDisplayRequest() async throws {
        let (plugin, _) = try await activated()
        plugin.isEnabled = false

        XCTAssertNil(plugin.displayRequest)
    }

    func testPluginPinsItselfToTheFarRight() {
        XCTAssertEqual(SystemStatsPlugin().closedNotchPosition, .farRight)
    }

    // MARK: - Configuration

    func testEveryRingIsVisibleByDefaultIncludingGPU() async throws {
        let (plugin, _) = try await activated()
        let configuration = plugin.configuration

        XCTAssertTrue(configuration.showCPU)
        XCTAssertTrue(configuration.showGPU)
        XCTAssertTrue(configuration.showRAM)
        XCTAssertTrue(configuration.showDisk)
        XCTAssertTrue(configuration.showNetwork)
    }

    func testTogglingARingIsReflectedInTheConfiguration() async throws {
        let (plugin, _) = try await activated()

        plugin.showGPU = false
        plugin.showDisk = false

        XCTAssertFalse(plugin.configuration.showGPU)
        XCTAssertFalse(plugin.configuration.showDisk)
        XCTAssertTrue(plugin.configuration.showCPU)
    }
}
