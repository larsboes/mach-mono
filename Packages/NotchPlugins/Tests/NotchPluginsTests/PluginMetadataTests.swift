import XCTest
import NotchCore
import NotchServices
import NotchSoundscapePlugin
@testable import NotchPlugins

@MainActor
final class PluginMetadataTests: XCTestCase {

    // MARK: - Helpers

    private func activatedPlugin<P: NotchPlugin>(_ plugin: P) async throws -> P {
        let mock = MockMusicService()
        let services = TestNotchServiceProvider(music: mock)
        let settings = MockNotchSettings()
        let context = PluginContext(
            settings: PluginSettings(pluginId: plugin.id),
            services: services,
            eventBus: PluginEventBus(),
            appState: MockAppState(),
            mediaSettings: settings
        )
        try await plugin.activate(context: context)
        return plugin
    }

    // MARK: - CalendarPlugin

    func testCalendarPluginID() {
        XCTAssertEqual(CalendarPlugin().id, PluginID.calendar)
    }

    func testCalendarPluginMetadataComplete() {
        let plugin = CalendarPlugin()
        XCTAssertFalse(plugin.metadata.name.isEmpty)
        XCTAssertFalse(plugin.metadata.icon.isEmpty)
        XCTAssertEqual(plugin.metadata.category, .productivity)
    }

    func testCalendarPluginActivatesAndDeactivates() async throws {
        let plugin = try await activatedPlugin(CalendarPlugin())
        XCTAssertTrue(plugin.state.isActive)
        await plugin.deactivate()
        XCTAssertFalse(plugin.state.isActive)
    }

    // MARK: - WeatherPlugin

    func testWeatherPluginID() {
        XCTAssertEqual(WeatherPlugin().id, PluginID.weather)
    }

    func testWeatherPluginNoDisplayRequestWhenNoData() async throws {
        let plugin = try await activatedPlugin(WeatherPlugin())
        defer { Task { await plugin.deactivate() } }
        // No weather data provided — displayRequest should be nil
        XCTAssertNil(plugin.displayRequest)
    }

    func testWeatherPluginActivatesAndDeactivates() async throws {
        let plugin = try await activatedPlugin(WeatherPlugin())
        XCTAssertTrue(plugin.state.isActive)
        await plugin.deactivate()
        XCTAssertFalse(plugin.state.isActive)
    }

    // MARK: - ShelfPlugin

    func testShelfPluginID() {
        XCTAssertEqual(ShelfPlugin().id, PluginID.shelf)
    }

    func testShelfPluginMetadataComplete() {
        let plugin = ShelfPlugin()
        XCTAssertFalse(plugin.metadata.name.isEmpty)
        XCTAssertFalse(plugin.metadata.icon.isEmpty)
    }

    func testShelfPluginActivatesAndDeactivates() async throws {
        let plugin = try await activatedPlugin(ShelfPlugin())
        XCTAssertTrue(plugin.state.isActive)
        await plugin.deactivate()
        XCTAssertFalse(plugin.state.isActive)
    }

    // MARK: - ClipboardPlugin

    func testClipboardPluginID() {
        XCTAssertEqual(ClipboardPlugin().id, PluginID.clipboard)
    }

    func testClipboardPluginActivatesAndDeactivates() async throws {
        let plugin = try await activatedPlugin(ClipboardPlugin())
        XCTAssertTrue(plugin.state.isActive)
        await plugin.deactivate()
        XCTAssertFalse(plugin.state.isActive)
    }

    // MARK: - NotificationsPlugin

    func testNotificationsPluginID() {
        XCTAssertEqual(NotificationsPlugin().id, PluginID.notifications)
    }

    func testNotificationsPluginActivatesAndDeactivates() async throws {
        let plugin = try await activatedPlugin(NotificationsPlugin())
        XCTAssertTrue(plugin.state.isActive)
        await plugin.deactivate()
        XCTAssertFalse(plugin.state.isActive)
    }

    // MARK: - TeleprompterPlugin

    func testTeleprompterPluginID() {
        XCTAssertEqual(TeleprompterPlugin().id, PluginID.teleprompter)
    }

    func testTeleprompterPluginDefaultDisplayRequestIsNil() async throws {
        let plugin = try await activatedPlugin(TeleprompterPlugin())
        defer { Task { await plugin.deactivate() } }
        XCTAssertNil(plugin.displayRequest)
    }

    // MARK: - WebcamPlugin

    func testWebcamPluginActivatesAndDeactivates() async throws {
        let plugin = try await activatedPlugin(WebcamPlugin())
        XCTAssertTrue(plugin.state.isActive)
        await plugin.deactivate()
        XCTAssertFalse(plugin.state.isActive)
    }

    // MARK: - SoundscapePlugin

    func testSoundscapePluginID() {
        XCTAssertEqual(SoundscapePlugin().id, PluginID.soundscape)
    }

    func testSoundscapePluginMetadataComplete() {
        let plugin = SoundscapePlugin()
        XCTAssertEqual(plugin.metadata.name, "Soundscape")
        XCTAssertFalse(plugin.metadata.icon.isEmpty)
        XCTAssertEqual(plugin.metadata.category, .media)
    }

    func testSoundscapePluginActivatesAndDeactivates() async throws {
        let plugin = try await activatedPlugin(SoundscapePlugin())
        XCTAssertTrue(plugin.state.isActive)
        await plugin.deactivate()
        XCTAssertFalse(plugin.state.isActive)
    }
}
