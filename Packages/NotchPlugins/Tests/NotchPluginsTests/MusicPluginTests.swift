import XCTest
import NotchCore
import NotchServices
@testable import NotchPlugins

// No setUp/tearDown — each test is self-contained (async throws test methods).
// async throws setUp on @MainActor XCTestCase classes crashes on macOS 26 beta
// with _swift_task_dealloc_specific LIFO violation when called for the 2nd+ test:
// XCTSwiftErrorObservation._observeErrors(in:) corrupts the task-local allocator.
// Multiple async throws test methods do NOT trigger this bug (ExportCoordinatorTests
// is evidence). Structuring tests as self-contained async throws methods is the
// correct workaround until Xcode 26 / macOS 26 ships a fix.
@MainActor
final class MusicPluginTests: XCTestCase {

    private func makeActivatedPlugin() async throws -> (MusicPlugin, MockMusicService) {
        let mock = MockMusicService()
        let services = TestNotchServiceProvider(music: mock)
        let settings = MockNotchSettings()
        let context = PluginContext(
            settings: PluginSettings(pluginId: PluginID.music),
            services: services,
            eventBus: PluginEventBus(),
            appState: MockAppState(),
            mediaSettings: settings
        )
        let plugin = MusicPlugin()
        try await plugin.activate(context: context)
        return (plugin, mock)
    }

    // MARK: - Display Request

    func testDisplayRequestWhenPlaying() async throws {
        let (plugin, mock) = try await makeActivatedPlugin()
        defer { plugin.deactivate_cancelOnly() }

        mock.playbackState = PlaybackState(bundleIdentifier: "com.apple.Music", isPlaying: true)
        mock.isPlayerIdle = false

        let request = plugin.displayRequest

        XCTAssertNotNil(request)
        XCTAssertEqual(request?.priority, .high)
        XCTAssertEqual(request?.category, DisplayRequest.music)
    }

    func testNoDisplayRequestWhenIdleAndPaused() async throws {
        let (plugin, mock) = try await makeActivatedPlugin()
        defer { plugin.deactivate_cancelOnly() }

        mock.playbackState = PlaybackState(bundleIdentifier: "com.apple.Music")
        mock.isPlayerIdle = true

        XCTAssertNil(plugin.displayRequest)
    }

    // MARK: - Now Playing

    func testNowPlayingInfoReflectsServiceState() async throws {
        let (plugin, mock) = try await makeActivatedPlugin()
        defer { plugin.deactivate_cancelOnly() }

        mock.currentTrack = TrackInfo(title: "Hello", artist: "Adele", album: "25")
        mock.playbackState = PlaybackState(bundleIdentifier: "com.apple.Music", isPlaying: true)

        let info = plugin.nowPlaying

        XCTAssertEqual(info?.track.title, "Hello")
        XCTAssertEqual(info?.track.artist, "Adele")
        XCTAssertTrue(info?.isPlaying ?? false)
    }
}
