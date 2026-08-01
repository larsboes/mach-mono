//
//  CommonTestStubs.swift
//  machNotchTests
//
//  Shared stubs and mocks for the full test suite.
//  Import @testable import machNotch in the consuming test file.
//

import AVFoundation
import Combine
import CoreBluetooth
import CoreLocation
import EventKit
import MacroVisionKit
import UserNotifications
import XCTest
import MachIntelligenceKit

@testable import machNotch

// MARK: - TestNotchServiceProvider

/// Minimal NotchServiceProvider for test isolation.
/// Only the services injected at init are controllable — every other service is a no-op stub.
@MainActor
final class TestNotchServiceProvider: NotchServiceProvider {

    // MediaServiceProvider
    let music: any MusicServiceProtocol
    let lyrics: any LyricsServiceProtocol
    let sound: any SoundServiceProtocol

    // SystemServiceProvider
    let volume: any VolumeServiceProtocol
    let brightness: any BrightnessServiceProtocol
    let keyboardBacklight: any KeyboardBacklightServiceProtocol
    let battery: any BatteryServiceProtocol
    let systemStats: any SystemStatsServiceProtocol
    let xpcHelper: any XPCHelperServiceProtocol
    let fullScreen: any FullScreenServiceProtocol

    // StorageServiceProvider
    let shelf: any ShelfServiceProtocol
    let temporaryFileStorage: any TemporaryFileStorageServiceProtocol
    let imageProcessing: any ImageProcessingServiceProtocol
    let thumbnails: any ThumbnailServiceProtocol
    let shelfImageProcessor: any ShelfImageProcessorProtocol
    let shelfFileHandler: any ShelfFileHandlerProtocol
    let quickLook: any QuickLookServiceProtocol
    let quickShare: QuickShareService

    // UIServiceProvider
    let notifications: any NotificationServiceProtocol
    let systemNotificationObserver: any SystemNotificationObserverProtocol
    let sharing: any SharingServiceProtocol
    let dragDrop: any DragDropServiceProtocol
    let webcam: any WebcamServiceProtocol
    let face: any FaceServiceProtocol

    // PluginExtensionServiceProvider
    let apiRouteRegistrar: (any APIRouteRegistrar)? = nil
    let ai: any AITextGenerationService
    let aiEmbedding: any AIEmbeddingService
    let bluetooth: (any BluetoothServiceProtocol)? = nil
    let bluetoothManager: any BluetoothStateServiceProtocol
    let notesManager: any NotesServiceProtocol
    let clipboardManager: any ClipboardServiceProtocol
    let calendar: any CalendarServiceProtocol
    let weather: any WeatherServiceProtocol

    init(music: any MusicServiceProtocol) {
        self.music = music

        let stubSharing = StubSharingService()
        let stubTempStorage = StubTemporaryStorage()
        let stubShelfImageProcessor = StubShelfImageProcessor()
        let stubShelfFileHandler = StubShelfFileHandler(tempStorage: stubTempStorage)

        self.lyrics = StubLyricsService()
        self.sound = StubSoundService()
        self.volume = StubVolumeService()
        self.brightness = StubBrightnessService()
        self.keyboardBacklight = StubKeyboardBacklightService()
        self.battery = StubBatteryService()
        self.systemStats = StubSystemStatsService()
        self.xpcHelper = StubXPCHelperService()
        self.fullScreen = StubFullScreenService()
        self.shelf = StubShelfService(
            imageProcessor: stubShelfImageProcessor,
            fileHandler: stubShelfFileHandler
        )
        self.temporaryFileStorage = stubTempStorage
        self.imageProcessing = StubImageProcessingService()
        self.thumbnails = StubThumbnailService()
        self.shelfImageProcessor = stubShelfImageProcessor
        self.shelfFileHandler = stubShelfFileHandler
        self.quickLook = StubQuickLookService()
        self.quickShare = QuickShareService(
            temporaryFileStorage: stubTempStorage,
            sharingStateManager: stubSharing,
            discoverOnInit: false
        )
        self.notifications = StubNotificationService()
        self.systemNotificationObserver = StubSystemNotificationObserver()
        self.sharing = stubSharing
        self.dragDrop = StubDragDropService()
        self.webcam = StubWebcamService()
        self.face = StubFaceService()
        self.ai = StubAIService()
        self.aiEmbedding = StubAIEmbeddingService()
        self.bluetoothManager = StubBluetoothStateService()
        self.notesManager = StubNotesService()
        self.clipboardManager = StubClipboardService()
        self.calendar = StubCalendarService()
        self.weather = StubWeatherService()
    }
}

// MARK: - MockMusicService

@MainActor
@Observable
final class MockMusicService: MusicServiceProtocol {

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

    @ObservationIgnored private let _playbackStateSubject = PassthroughSubject<PlaybackState, Never>()
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        _playbackStateSubject.eraseToAnyPublisher()
    }

    @ObservationIgnored private let _sneakPeekSubject = PassthroughSubject<SneakPeekRequest, Never>()
    var sneakPeekPublisher: AnyPublisher<SneakPeekRequest, Never> {
        _sneakPeekSubject.eraseToAnyPublisher()
    }

    func play() async {}
    func pause() async {}
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

// MARK: - MockAppState

final class MockAppState: AppStateProviding {
    var isScreenLocked: Bool = false
}

// MARK: - No-op Stubs

@MainActor @Observable final class StubLyricsService: LyricsServiceProtocol {
    var currentLyrics: String = ""
    var isFetchingLyrics: Bool = false
    var syncedLyrics: [(time: Double, text: String)] = []
    func fetchLyrics(bundleIdentifier: String?, title: String, artist: String) async {}
    func clearLyrics() {}
    func lyricLine(at elapsed: Double) -> String { "" }
}

struct StubSoundService: SoundServiceProtocol, @unchecked Sendable {
    func play(_ sound: SoundEffect) {}
}

@MainActor @Observable final class StubVolumeService: VolumeServiceProtocol {
    var rawVolume: Float = 0.5
    var isMuted: Bool = false
    func increase(stepDivisor: Float) {}
    func decrease(stepDivisor: Float) {}
    func toggleMuteAction() {}
    func setAbsolute(_ value: Float) {}
    func refresh() {}
}

@MainActor @Observable final class StubBrightnessService: BrightnessServiceProtocol {
    var rawBrightness: Float = 0.5
    func setRelative(delta: Float) {}
    func setAbsolute(value: Float) {}
    func refresh() {}
}

@MainActor @Observable final class StubKeyboardBacklightService: KeyboardBacklightServiceProtocol {
    var rawBrightness: Float = 0.5
    func setRelative(delta: Float) {}
    func setAbsolute(value: Float) {}
    func refresh() {}
}

@MainActor @Observable final class StubBatteryService: BatteryServiceProtocol {
    var levelBattery: Float = 80
    var isPluggedIn: Bool = false
    var isCharging: Bool = false
    var isInLowPowerMode: Bool = false
    var timeToFullCharge: Int = 0
    var maxCapacity: Float = 100
    var statusText: String = "80%"
    var snapshot: BatterySnapshot {
        BatterySnapshot(
            levelBattery: levelBattery, isPluggedIn: isPluggedIn,
            isCharging: isCharging, isInLowPowerMode: isInLowPowerMode,
            timeToFullCharge: timeToFullCharge, maxCapacity: maxCapacity,
            statusText: statusText)
    }
    func alertKind(initial: Bool) -> BatteryAlertKind? { nil }
}

@MainActor @Observable final class StubSystemStatsService: SystemStatsServiceProtocol {
    var stats: SystemStats = .zero
    var history: [SystemStats] = []
    var refreshInterval: TimeInterval = 3
    func startMonitoring() {}
    func stopMonitoring() {}
    func refresh() {}
}

@MainActor
final class StubXPCHelperService: XPCHelperServiceProtocol {
    var isMonitoring: Bool = false
    func requestAccessibilityAuthorization() {}
    func isAccessibilityAuthorized() async -> Bool { false }
    func ensureAccessibilityAuthorization(promptIfNeeded: Bool) async -> Bool { false }
    func startMonitoringAccessibilityAuthorization(every interval: TimeInterval) {}
    func stopMonitoringAccessibilityAuthorization() {}
    func isScreenBrightnessAvailable() async -> Bool { false }
    func currentScreenBrightness() async -> Float? { nil }
    func setScreenBrightness(_ value: Float) async -> Bool { false }
    func isKeyboardBrightnessAvailable() async -> Bool { false }
    func currentKeyboardBrightness() async -> Float? { nil }
    func setKeyboardBrightness(_ value: Float) async -> Bool { false }
    func getBluetoothDeviceMinorClass(with deviceName: String) async -> String? { nil }
}

struct StubFullScreenService: FullScreenServiceProtocol, @unchecked Sendable {
    var currentFullScreenApps: [FullScreenMonitor.SpaceInfo] { [] }
    func spaceChanges() async -> AsyncStream<[FullScreenMonitor.SpaceInfo]> {
        AsyncStream { _ in }
    }
}

@MainActor @Observable final class StubShelfService: ShelfServiceProtocol, @unchecked Sendable {
    var items: [ShelfItem] = []
    let selection: ShelfSelectionModel = ShelfSelectionModel()
    let imageProcessor: any ShelfImageProcessorProtocol
    let fileHandler: any ShelfFileHandlerProtocol
    var isLoading: Bool = false
    var isEmpty: Bool { items.isEmpty }

    init(imageProcessor: any ShelfImageProcessorProtocol, fileHandler: any ShelfFileHandlerProtocol) {
        self.imageProcessor = imageProcessor
        self.fileHandler = fileHandler
    }

    func add(_ newItems: [ShelfItem]) {}
    func remove(_ item: ShelfItem) {}
    func updateBookmark(for item: ShelfItem, bookmark: Data) {}
    func load(_ providers: [NSItemProvider]) {}
    func cleanupInvalidItems() {}
    func resolveAndUpdateBookmark(for item: ShelfItem) -> URL? { nil }
    func resolveFileURLs(for items: [ShelfItem]) -> [URL] { [] }
    func flushSync() {}
}

struct StubTemporaryStorage: TemporaryFileStorageServiceProtocol, @unchecked Sendable {
    func createTempFile(for type: TempFileType) async -> URL? { nil }
    func removeTemporaryFileIfNeeded(at url: URL) {}
    func createZip(from urls: [URL], suggestedName: String?) async -> URL? { nil }
}

struct StubImageProcessingService: ImageProcessingServiceProtocol, @unchecked Sendable {
    func removeBackground(from url: URL) async throws -> URL? { nil }
    func convertImage(from url: URL, options: ImageConversionOptions) async throws -> URL? { nil }
    func createPDF(from imageURLs: [URL], outputName: String?) async throws -> URL? { nil }
    func isImageFile(_ url: URL) -> Bool { false }
}

struct StubThumbnailService: ThumbnailServiceProtocol, @unchecked Sendable {
    func thumbnail(for url: URL, size: CGSize) async -> CGImage? { nil }
    func clearCache() async {}
    func clearCache(for url: URL) async {}
}

@MainActor
final class StubShelfImageProcessor: ShelfImageProcessorProtocol {
    func removeBackground(
        from item: ShelfItem, service: ShelfServiceProtocol,
        completion: @escaping (Error?) -> Void
    ) {}
    func createPDF(
        from items: [ShelfItem], service: ShelfServiceProtocol,
        completion: @escaping (Error?) -> Void
    ) {}
    func convertImage(
        item: ShelfItem, options: ImageConversionOptions, service: ShelfServiceProtocol,
        completion: @escaping (Error?) -> Void
    ) {}
    func loadThumbnail(for url: URL, size: CGSize) async -> NSImage? { nil }
    func isImageFile(_ url: URL) -> Bool { false }
}

@MainActor
final class StubShelfFileHandler: ShelfFileHandlerProtocol, @unchecked Sendable {
    let temporaryFileStorage: any TemporaryFileStorageServiceProtocol
    init(tempStorage: any TemporaryFileStorageServiceProtocol) {
        self.temporaryFileStorage = tempStorage
    }
    func rename(
        item: ShelfItem, newName: String, service: ShelfServiceProtocol,
        completion: @escaping (Bool) -> Void
    ) {}
    func showInFinder(items: [ShelfItem], service: ShelfServiceProtocol) {}
    func copyPath(items: [ShelfItem]) {}
    func compress(items: [ShelfItem], service: ShelfServiceProtocol) {}
    func open(items: [ShelfItem], with appURL: URL?) {}
}

@MainActor @Observable final class StubQuickLookService: QuickLookServiceProtocol {
    var urls: [URL] = []
    var selectedURL: URL?
    var isQuickLookOpen: Bool = false
    func show(urls: [URL], selectFirst: Bool, slideshow: Bool) {}
    func hide() {}
    func updateSelection(urls: [URL]) {}
}

@MainActor @Observable final class StubNotificationService: NotificationServiceProtocol {
    var notifications: [NotchNotification] = []
    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    func requestAuthorization() {}
    func addNotification(_ notification: NotchNotification) {}
    func markAllAsRead() {}
    func clearAll() {}
    func removeNotification(_ notification: NotchNotification) {}
    func markAsRead(_ notification: NotchNotification) {}
    func refreshAuthorizationStatus() {}
}

final class StubSystemNotificationObserver: SystemNotificationObserverProtocol {
    var isObserving: Bool = false
    func startObserving() {}
    func stopObserving() {}
}

@MainActor @Observable final class StubSharingService: SharingServiceProtocol {
    var preventNotchClose: Bool = false
    func requestCloseIfReady() {}
    func beginInteraction() {}
    func endInteraction() {}
    func makeDelegate(onEnd: (() -> Void)?) -> SharingLifecycleDelegate {
        SharingLifecycleDelegate(id: UUID(), onEnd: onEnd ?? {}, onBegin: {}, onFinish: {})
    }
}

@MainActor
final class StubDragDropService: DragDropServiceProtocol {
    var onDragEntersNotchRegion: (() -> Void)?
    var onDragExitsNotchRegion: (() -> Void)?
    var onDragMove: ((CGPoint) -> Void)?
    func startMonitoring() {}
    func stopMonitoring() {}
    func updateNotchRegion(_ region: CGRect) {}
}

@MainActor @Observable final class StubWebcamService: WebcamServiceProtocol {
    var previewLayer: AVCaptureVideoPreviewLayer?
    var isSessionRunning: Bool = false
    var cameraAvailable: Bool = false
    var authorizationStatus: AVAuthorizationStatus = .notDetermined
    var availableCameras: [WebcamDeviceDescriptor] = []
    var selectedCameraID: String = ""
    var startSessionCallCount = 0
    var stopSessionCallCount = 0
    var authorizationRequestCallCount = 0
    var refreshAuthorizationCallCount = 0
    var refreshCameraDevicesCallCount = 0

    func startSession() {
        startSessionCallCount += 1
        isSessionRunning = true
    }

    func stopSession() {
        stopSessionCallCount += 1
        isSessionRunning = false
    }

    func refreshAuthorizationStatus() {
        refreshAuthorizationCallCount += 1
    }

    func refreshCameraDevices() {
        refreshCameraDevicesCallCount += 1
    }

    func checkAndRequestVideoAuthorization() {
        authorizationRequestCallCount += 1
    }
}

@MainActor
final class StubFaceService: FaceServiceProtocol {
    var eyeOffset: CGSize = .zero
    var isSleepy: Bool = false
    func startMonitoring() {}
    func stopMonitoring() {}
}

final class StubAIService: AITextGenerationService {
    var available = false
    var isAvailable: Bool {
        get async { available }
    }
    func rewrite(_ text: String, style: AIRewriteStyle) async throws -> String { text }
    func rewriteStream(_ text: String, style: AIRewriteStyle) -> AsyncThrowingStream<String, Error> {
        stream(text)
    }
    func summarize(_ text: String) async throws -> String { text }
    func summarizeStream(_ text: String) -> AsyncThrowingStream<String, Error> {
        stream(text)
    }
    func section(_ text: String) async throws -> [String] { [text] }
    func draftIntro(topic: String, durationSeconds: Int) async throws -> String { "" }
    func draftIntroStream(topic: String, durationSeconds: Int) -> AsyncThrowingStream<String, Error> {
        stream("")
    }

    private func stream(_ text: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(text)
            continuation.finish()
        }
    }
}

final class StubAIEmbeddingService: AIEmbeddingService {
    func embedding(for text: String) async throws -> [Float] {
        []
    }
}

@MainActor @Observable final class StubBluetoothStateService: BluetoothStateServiceProtocol {
    var connectedDevices: [BluetoothDevice] = []
    var bluetoothState: CBManagerState = .unknown
    var isInitialized: Bool = false
    func initializeBluetooth() {}
}

@MainActor @Observable final class StubNotesService: NotesServiceProtocol {
    var notes: [NoteItem] = []
    func addNote(title: String, content: String) {}
    func updateNote(_ note: NoteItem) {}
    func deleteNote(_ note: NoteItem) {}
}

@MainActor @Observable final class StubClipboardService: ClipboardServiceProtocol {
    var items: [ClipboardItem] = []
    func startMonitoring() {}
    func stopMonitoring() {}
    func clearHistory() {}
    func copyToPasteboard(_ item: ClipboardItem) {}
    func deleteItem(_ item: ClipboardItem) {}
}

@MainActor @Observable final class StubCalendarService: CalendarServiceProtocol {
    var events: [EventModel] = []
    var currentWeekStartDate: Date = Date()
    var calendarAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    var reminderAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    var selectedCalendarIDs: Set<String> = []
    var allCalendars: [CalendarModel] = []
    var eventCalendars: [CalendarModel] = []
    var reminderLists: [CalendarModel] = []
    func refreshAuthorizationStatus() {}
    func checkCalendarAuthorization() async {}
    func checkReminderAuthorization() async {}
    func updateCurrentDate(_ date: Date) async {}
    func setCalendarSelected(_ calendar: CalendarModel, isSelected: Bool) async {}
    func setReminderCompleted(reminderID: String, completed: Bool) async {}
    func reloadCalendarAndReminderLists() async {}
    func getCalendarSelected(_ calendar: CalendarModel) -> Bool { false }
}

@MainActor @Observable final class StubWeatherService: WeatherServiceProtocol {
    var currentWeather: WeatherData?
    var activeSource: WeatherDataSource?
    var isLoading: Bool = false
    var errorMessage: String?
    var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    func checkLocationAuthorization() {}
    func startUpdatingWeather() {}
    func stopUpdatingWeather() {}
    func fetchWeather() {}
    func refreshWeather() {}
}
