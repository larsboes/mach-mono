//
//  MusicPluginTests.swift
//  boringNotchTests
//
//  Created for Phase 6: Unit Tests
//

import XCTest
import Combine
import SwiftUI
@testable import boringNotch

@MainActor
final class MusicPluginTests: XCTestCase {
    
    var plugin: MusicPlugin!
    var mockService: MockMusicService!
    var context: PluginContext!
    
    override func setUp() async throws {
        // Setup dependencies
        mockService = MockMusicService()
        
        let container = ServiceContainer(
            music: mockService,
            sound: MockSoundService(),
            calendar: MockCalendarService(),
            shelf: MockShelfService(),
            weather: MockWeatherService(),
            webcam: MockWebcamService(),
            notifications: MockNotificationService(),
            volume: MockVolumeService(),
            brightness: MockBrightnessService(),
            keyboardBacklight: MockKeyboardBacklightService(),
            battery: MockBatteryService(),
            thumbnails: MockThumbnailService(),
            lyrics: MockLyricsService(),
            sharing: MockSharingService(),
            imageProcessing: MockImageProcessingService(),
            temporaryFileStorage: MockTemporaryFileStorageService(),
            shelfImageProcessor: MockShelfImageProcessor(),
            shelfFileHandler: MockShelfFileHandler()
        )
        
        let eventBus = PluginEventBus()
        let appState = MockAppState()
        
        context = PluginContext(
            settings: PluginSettings(pluginId: "com.boringnotch.music"),
            services: container,
            eventBus: eventBus,
            appState: appState
        )
        
        plugin = MusicPlugin()
        try await plugin.activate(context: context)
    }
    
    override func tearDown() async throws {
        await plugin.deactivate()
        plugin = nil
        mockService = nil
        context = nil
    }
    
    func testDisplayRequestWhenPlaying() async {
        // GIVEN: Music is playing
        mockService.playbackState = PlaybackState(
            bundleIdentifier: "com.apple.Music",
            isPlaying: true,
            title: "Test Song",
            artist: "Test Artist",
            album: "Test Album",
            duration: 180,
            currentTime: 10
        )
        mockService.isPlayerIdle = false
        
        // WHEN: We check display request
        let request = plugin.displayRequest
        
        // THEN: It should request high priority display
        XCTAssertNotNil(request)
        XCTAssertEqual(request?.priority, .high)
        XCTAssertEqual(request?.category, .music)
    }
    
    func testNoDisplayRequestWhenPaused() async {
        // GIVEN: Music is paused
        mockService.playbackState = PlaybackState(
            bundleIdentifier: "com.apple.Music",
            isPlaying: false
        )
        mockService.isPlayerIdle = true // Idle means stopped/paused for long time
        
        // WHEN: We check display request
        let request = plugin.displayRequest
        
        // THEN: It should not request display
        XCTAssertNil(request)
    }
    
    func testNowPlayingInfo() async {
        // GIVEN: A specific track
        mockService.currentTrack = TrackInfo(title: "Hello", artist: "Adele", album: "25")
        mockService.playbackState = PlaybackState(bundleIdentifier: "", isPlaying: true)
        
        // WHEN: We access nowPlaying
        let info = plugin.nowPlaying
        
        // THEN: It should reflect the service data
        XCTAssertEqual(info?.track.title, "Hello")
        XCTAssertEqual(info?.track.artist, "Adele")
        XCTAssertTrue(info?.isPlaying ?? false)
    }
}

// MARK: - Mocks

@MainActor
class MockMusicService: MusicServiceProtocol {
    // Observable conformance handled by @Observable macro in Swift 5.9,
    // but for mocks we just use standard properties since we don't need UI updates in unit tests
    
    var playbackState = PlaybackState(bundleIdentifier: "") {
        didSet { _playbackStateSubject.send(playbackState) }
    }
    var currentTrack: TrackInfo?
    var artwork: NSImage?
    var avgColor: NSColor = .black
    var progress: Double = 0
    var volume: Double = 0.5
    var isShuffled: Bool = false
    var repeatMode: RepeatMode = .off
    var isFavorite: Bool = false
    
    var currentLyrics: String = ""
    var isFetchingLyrics: Bool = false
    var syncedLyrics: [(time: Double, text: String)] = []
    
    var songDuration: TimeInterval = 0
    var elapsedTime: TimeInterval = 0
    var timestampDate: Date = Date()
    var playbackRate: Double = 1
    var bundleIdentifier: String?
    var canFavoriteTrack: Bool = true
    var isPlayerIdle: Bool = true
    var isNowPlayingDeprecated: Bool = false
    var volumeControlSupported: Bool = true
    
    private let _playbackStateSubject = PassthroughSubject<PlaybackState, Never>()
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        _playbackStateSubject.eraseToAnyPublisher()
    }
    
    private let _sneakPeekSubject = PassthroughSubject<SneakPeekRequest, Never>()
    var sneakPeekPublisher: AnyPublisher<SneakPeekRequest, Never> {
        _sneakPeekSubject.eraseToAnyPublisher()
    }
    
    func play() async { playbackState.isPlaying = true }
    func pause() async { playbackState.isPlaying = false }
    func togglePlayPause() async { playbackState.isPlaying.toggle() }
    func next() async {}
    func previous() async {}
    func seek(to progress: Double) async {}
    func setVolume(_ volume: Double) async { self.volume = volume }
    func toggleShuffle() async { isShuffled.toggle() }
    func toggleRepeat() async {}
    func toggleFavorite() async { isFavorite.toggle() }
    func openMusicApp() async {}
    func syncVolumeFromActiveApp() async {}
    func destroy() {}
    func forceUpdate() {}
    func estimatedPlaybackPosition(at date: Date) -> TimeInterval { 0 }
}

class MockAppState: AppStateProviding {
    var isScreenLocked: Bool = false
    var isFullscreen: Bool = false
}

// MARK: - Additional Mocks

class MockSoundService: SoundServiceProtocol {
    func play(_ sound: SoundEffect) {}
}

class MockCalendarService: CalendarServiceProtocol {
    var events: [CalendarEvent] = []
    func requestAccess() async -> Bool { true }
}

class MockShelfService: ShelfServiceProtocol {
    var items: [ShelfItem] = []
    func load(_ providers: [NSItemProvider]) {}
    func flushSync() {}
}

class MockWeatherService: WeatherServiceProtocol {
    var weather: WeatherData?
    func refresh() async {}
}

class MockWebcamService: WebcamServiceProtocol {
    var isCameraActive: Bool = false
    func start() {}
    func stop() {}
}

class MockNotificationService: NotificationServiceProtocol {
    func post(_ notification: Notification) {}
}

class MockVolumeService: VolumeServiceProtocol {
    var volume: Float = 0.5
    var isMuted: Bool = false
    func setVolume(_ volume: Float) {}
    func toggleMute() {}
}

class MockBrightnessService: BrightnessServiceProtocol {
    var brightness: Float = 0.5
    func setBrightness(_ brightness: Float) {}
}

class MockKeyboardBacklightService: KeyboardBacklightServiceProtocol {
    var brightness: Float = 0.5
    func setBrightness(_ brightness: Float) {}
}

class MockBatteryService: BatteryServiceProtocol {
    var level: Double = 0.8
    var isCharging: Bool = false
    var isPluggedIn: Bool = false
    var isInLowPowerMode: Bool = false
    var timeRemaining: TimeInterval?
    var statusText: String = "80%"
    var levelBattery: Float = 80.0
    var timeToFullCharge: Int = 0
    var maxCapacity: Float = 100.0
}

class MockThumbnailService: ThumbnailServiceProtocol {
    func generateThumbnail(for url: URL) async -> NSImage? { nil }
}

class MockLyricsService: LyricsServiceProtocol {
    var currentLyrics: String = ""
    var isFetchingLyrics: Bool = false
    var syncedLyrics: [(time: Double, text: String)] = []
    func fetchLyrics(for track: TrackInfo) async {}
}

class MockSharingService: SharingServiceProtocol {
    var preventNotchClose: Bool = false
}

class MockImageProcessingService: ImageProcessingServiceProtocol {
    func process(_ image: NSImage) -> NSImage { image }
}

class MockTemporaryFileStorageService: TemporaryFileStorageServiceProtocol {
    func store(_ data: Data, name: String) -> URL { URL(fileURLWithPath: "/") }
}

class MockShelfImageProcessor: ShelfImageProcessorProtocol {
    func process(_ item: ShelfItem) async -> NSImage? { nil }
}

class MockShelfFileHandler: ShelfFileHandlerProtocol {
    func handle(_ url: URL) async {}
}
