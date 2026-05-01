import Foundation

/// Container for all services used by plugins.
/// Provides dependency injection for plugin activation.
///
/// Services are optional until their implementations are created during migration.
/// This allows incremental adoption of the plugin architecture.
@MainActor
final class ServiceContainer: NotchServiceProvider {
    // MARK: - Core Services

    /// Music playback service (wraps MusicManager)
    let music: any MusicServiceProtocol

    /// Calendar service (wraps CalendarService)
    public let calendar: any CalendarServiceProtocol

    /// Sound service
    public let sound: any SoundServiceProtocol

    /// Shelf storage service (wraps ShelfService)
    public let shelf: any ShelfServiceProtocol

    /// Weather service (wraps WeatherManager)
    public let weather: any WeatherServiceProtocol

    // MARK: - System Services

    /// Volume control service (wraps VolumeManager)
    public let volume: any VolumeServiceProtocol

    /// Brightness control service (wraps BrightnessManager)
    public let brightness: any BrightnessServiceProtocol

    /// Keyboard backlight control service (wraps KeyboardBacklightManager)
    public let keyboardBacklight: any KeyboardBacklightServiceProtocol

    /// Battery status service (wraps BatteryService)
    public let battery: any BatteryServiceProtocol

    /// Thumbnail generation service
    public let thumbnails: any ThumbnailServiceProtocol

    /// Lyrics fetching service
    public let lyrics: any LyricsServiceProtocol

    /// Sharing state service
    public let sharing: any SharingServiceProtocol

    /// Image processing service
    public let imageProcessing: any ImageProcessingServiceProtocol

    /// Temporary file storage service
    public let temporaryFileStorage: any TemporaryFileStorageServiceProtocol

    /// Webcam service (wraps WebcamManager)
    public let webcam: any WebcamServiceProtocol

    /// Notifications service (wraps NotificationCenterManager)
    public let notifications: any NotificationServiceProtocol

    /// API Route Registrar
    public var apiRouteRegistrar: (any APIRouteRegistrar)?

    /// AI Service (domain-level text generation)
    public let ai: any AITextGenerationService

    /// Bluetooth service (wraps BluetoothManager) - optional until implemented
    var bluetooth: (any BluetoothServiceProtocol)?

    /// Concrete BluetoothManager for views that need @Observable access
    let bluetoothManager: any BluetoothStateServiceProtocol

    /// Notes manager for shelf notes
    let notesManager: any NotesServiceProtocol

    /// Clipboard manager for clipboard history
    let clipboardManager: any ClipboardServiceProtocol

    /// System notification observer for capturing macOS notification banners
    let systemNotificationObserver: any SystemNotificationObserverProtocol

    /// XPC Helper for privileged operations
    let xpcHelper: any XPCHelperServiceProtocol

    /// Face tracking service
    public let face: any FaceServiceProtocol
    
    /// Drag and drop detection service
    public let dragDrop: any DragDropServiceProtocol

    // MARK: - Shelf Helpers

    /// Shelf image processor
    public let shelfImageProcessor: any ShelfImageProcessorProtocol

    /// Shelf file handler
    public let shelfFileHandler: any ShelfFileHandlerProtocol

    /// Quick Look preview service
    public let quickLook: any QuickLookServiceProtocol

    /// Quick Share service
    public let quickShare: QuickShareService

    // MARK: - Initialization

    /// Default initializer - creates services that are ready
    init(eventBus: PluginEventBus, settings: any NotchSettings, xpcHelper: (any XPCHelperServiceProtocol)? = nil) {
        let xpcHelper = xpcHelper ?? XPCHelperClient.shared
        self.music = MusicService(manager: MusicManager(settings: settings))
        self.sound = SoundService()
        self.battery = BatteryService(eventBus: eventBus, settings: settings)
        self.calendar = CalendarService(settings: settings)
        self.weather = WeatherService(settings: settings)
        self.face = FaceService(settings: settings)
        self.dragDrop = DragDropService()

        self.temporaryFileStorage = TemporaryFileStorageService()
        self.imageProcessing = ImageProcessingService(temporaryFileStorage: self.temporaryFileStorage)
        self.thumbnails = ThumbnailService()

        // Initialize Shelf helpers first
        self.shelfImageProcessor = ShelfImageProcessor(imageProcessingService: self.imageProcessing, thumbnailService: self.thumbnails)
        self.shelfFileHandler = ShelfFileHandler(temporaryFileStorage: self.temporaryFileStorage)
        self.shelf = ShelfService(imageProcessor: self.shelfImageProcessor, fileHandler: self.shelfFileHandler)

        self.lyrics = LyricsService()
        self.webcam = WebcamManager()
        self.notifications = NotificationCenterManager(settings: settings)
        self.systemNotificationObserver = SystemNotificationObserver(notificationManager: self.notifications)
        self.volume = VolumeManager(eventBus: eventBus)
        self.brightness = BrightnessManager(eventBus: eventBus, xpcHelper: xpcHelper)
        self.keyboardBacklight = KeyboardBacklightManager(eventBus: eventBus, xpcHelper: xpcHelper)
        self.sharing = SharingStateManager()
        self.quickLook = QuickLookService()
        self.quickShare = QuickShareService(temporaryFileStorage: self.temporaryFileStorage, sharingStateManager: self.sharing)
        self.bluetoothManager = BluetoothManager(settings: settings)
        self.notesManager = NotesManager()
        self.clipboardManager = ClipboardManager()
        self.xpcHelper = xpcHelper

        let aiSettings = settings
        let aiManager = AIManager(isEnabled: {
            aiSettings.isAIEnabled
        })
        self.ai = aiManager.textGeneration
    }

    /// Full initializer for testing or custom configurations
    init(
        music: any MusicServiceProtocol,
        sound: any SoundServiceProtocol,
        calendar: any CalendarServiceProtocol,
        shelf: any ShelfServiceProtocol,
        weather: any WeatherServiceProtocol,
        face: any FaceServiceProtocol,
        dragDrop: any DragDropServiceProtocol,
        webcam: any WebcamServiceProtocol,
        notifications: any NotificationServiceProtocol,
        systemNotificationObserver: SystemNotificationObserver,
        volume: any VolumeServiceProtocol,
        brightness: any BrightnessServiceProtocol,
        keyboardBacklight: any KeyboardBacklightServiceProtocol,
        battery: any BatteryServiceProtocol,
        thumbnails: any ThumbnailServiceProtocol,
        lyrics: any LyricsServiceProtocol,
        sharing: any SharingServiceProtocol,
        imageProcessing: any ImageProcessingServiceProtocol,
        temporaryFileStorage: any TemporaryFileStorageServiceProtocol,
        shelfImageProcessor: any ShelfImageProcessorProtocol,
        shelfFileHandler: any ShelfFileHandlerProtocol,
        quickLook: any QuickLookServiceProtocol,
        quickShare: QuickShareService,
        ai: any AITextGenerationService,
        bluetooth: (any BluetoothServiceProtocol)? = nil,
        bluetoothManager: any BluetoothStateServiceProtocol,
        notesManager: any NotesServiceProtocol,
        clipboardManager: any ClipboardServiceProtocol,
        xpcHelper: any XPCHelperServiceProtocol
    ) {
        self.music = music
        self.sound = sound
        self.calendar = calendar
        self.shelf = shelf
        self.weather = weather
        self.face = face
        self.dragDrop = dragDrop
        self.webcam = webcam
        self.notifications = notifications
        self.systemNotificationObserver = systemNotificationObserver
        self.volume = volume
        self.brightness = brightness
        self.keyboardBacklight = keyboardBacklight
        self.battery = battery
        self.thumbnails = thumbnails
        self.lyrics = lyrics
        self.sharing = sharing
        self.imageProcessing = imageProcessing
        self.temporaryFileStorage = temporaryFileStorage
        self.shelfImageProcessor = shelfImageProcessor
        self.shelfFileHandler = shelfFileHandler
        self.quickLook = quickLook
        self.quickShare = quickShare
        self.ai = ai
        self.bluetooth = bluetooth
        self.bluetoothManager = bluetoothManager
        self.notesManager = notesManager
        self.clipboardManager = clipboardManager
        self.xpcHelper = xpcHelper
    }
}
