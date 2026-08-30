import Foundation
import MachIntelligenceKit

/// Container for all services used by plugins.
/// Provides dependency injection for plugin activation.
///
/// Services are optional until their implementations are created during migration.
/// This allows incremental adoption of the plugin architecture.
@MainActor
public final class ServiceContainer: NotchServiceProvider {
    // MARK: - Core Services

    /// Music playback service (wraps MusicManager)
    public lazy var music: any MusicServiceProtocol = MusicService(manager: MusicManager(settings: settings))

    /// Calendar service (wraps CalendarService)
    public lazy var calendar: any CalendarServiceProtocol = CalendarService(settings: settings)

    /// Sound service
    public lazy var sound: any SoundServiceProtocol = SoundService()

    /// Shelf storage service (wraps ShelfService)
    public lazy var shelf: any ShelfServiceProtocol = ShelfService(
        imageProcessor: self.shelfImageProcessor, fileHandler: self.shelfFileHandler)

    /// Weather service (wraps WeatherManager)
    public lazy var weather: any WeatherServiceProtocol = WeatherService(settings: settings)

    // MARK: - System Services

    /// Volume control service (wraps VolumeManager)
    public lazy var volume: any VolumeServiceProtocol = VolumeManager(eventBus: eventBus)

    /// Brightness control service (wraps BrightnessManager)
    public lazy var brightness: any BrightnessServiceProtocol = BrightnessManager(
        eventBus: eventBus, xpcHelper: xpcHelper)

    /// Keyboard backlight control service (wraps KeyboardBacklightManager)
    public lazy var keyboardBacklight: any KeyboardBacklightServiceProtocol = KeyboardBacklightManager(
        eventBus: eventBus, xpcHelper: xpcHelper)

    /// Battery status service (wraps BatteryService)
    public lazy var battery: any BatteryServiceProtocol = BatteryService(eventBus: eventBus, settings: settings)

    /// System stats service (CPU, memory, disk, network)
    public lazy var systemStats: any SystemStatsServiceProtocol = SystemStatsService()

    /// Full Screen monitoring service
    public lazy var fullScreen: any FullScreenServiceProtocol = FullScreenService()

    /// Thumbnail generation service
    public lazy var thumbnails: any ThumbnailServiceProtocol = ThumbnailService()

    /// Lyrics fetching service
    public lazy var lyrics: any LyricsServiceProtocol = LyricsService()

    /// Sharing state service
    public lazy var sharing: any SharingServiceProtocol = SharingStateManager()

    /// Image processing service
    public lazy var imageProcessing: any ImageProcessingServiceProtocol = ImageProcessingService(
        temporaryFileStorage: self.temporaryFileStorage)

    /// Temporary file storage service
    public lazy var temporaryFileStorage: any TemporaryFileStorageServiceProtocol = TemporaryFileStorageService()

    /// Webcam service (wraps WebcamManager)
    public lazy var webcam: any WebcamServiceProtocol = WebcamManager(settings: settings)

    /// Notifications service (wraps NotificationCenterManager)
    public lazy var notifications: any NotificationServiceProtocol = NotificationCenterManager(settings: settings)

    /// API Route Registrar
    public var apiRouteRegistrar: (any APIRouteRegistrar)?

    /// AI Service (domain-level text generation)
    public lazy var ai: any AITextGenerationService = AITextGenerationServiceFactory.make(settings: settings)

    /// AI Embedding service (domain-level text embeddings)
    public lazy var aiEmbedding: any AIEmbeddingService = AIEmbeddingServiceFactory.make(settings: settings)

    /// Bluetooth service (wraps BluetoothManager) - optional until implemented
    public var bluetooth: (any BluetoothServiceProtocol)?

    /// Concrete BluetoothManager for views that need @Observable access
    public lazy var bluetoothManager: any BluetoothStateServiceProtocol = BluetoothManager(settings: settings)

    /// Notes manager for shelf notes
    public lazy var notesManager: any NotesServiceProtocol = NotesManager()

    /// Clipboard manager for clipboard history
    public lazy var clipboardManager: any ClipboardServiceProtocol = ClipboardManager()

    /// System notification observer for capturing macOS notification banners
    public lazy var systemNotificationObserver: any SystemNotificationObserverProtocol = SystemNotificationObserver(
        notificationManager: self.notifications)

    /// XPC Helper for privileged operations
    public let xpcHelper: any XPCHelperServiceProtocol

    /// Face tracking service
    public lazy var face: any FaceServiceProtocol = FaceService(settings: settings)

    /// Drag and drop detection service
    public lazy var dragDrop: any DragDropServiceProtocol = DragDropService()

    // MARK: - Shelf Helpers

    /// Shelf image processor
    public lazy var shelfImageProcessor: any ShelfImageProcessorProtocol = ShelfImageProcessor(
        imageProcessingService: self.imageProcessing, thumbnailService: self.thumbnails)

    /// Shelf file handler
    public lazy var shelfFileHandler: any ShelfFileHandlerProtocol = ShelfFileHandler(
        temporaryFileStorage: self.temporaryFileStorage)

    /// Quick Look preview service
    public lazy var quickLook: any QuickLookServiceProtocol = QuickLookService()

    /// Quick Share service
    public lazy var quickShare: QuickShareService = QuickShareService(
        temporaryFileStorage: self.temporaryFileStorage, sharingStateManager: self.sharing)

    // MARK: - Initialization

    // MARK: - Dependencies

    private let eventBus: PluginEventBus
    private let settings: any NotchSettings

    // MARK: - Initialization

    /// Stores dependencies and builds nothing.
    ///
    /// Every service above is a `lazy var`, so it is constructed on first use.
    /// Plugin descriptors are registered without constructing plugins, and a
    /// disabled plugin never asks for its services, so an eager container was
    /// undoing that laziness one layer down.
    public init(eventBus: PluginEventBus, settings: any NotchSettings, xpcHelper: (any XPCHelperServiceProtocol)? = nil)
    {
        self.eventBus = eventBus
        self.settings = settings
        self.xpcHelper = xpcHelper ?? XPCHelperClient.shared
    }
}
