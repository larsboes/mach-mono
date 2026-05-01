//
//  ServiceProviderProtocols.swift
//  boringNotch
//
//  ISP-compliant sub-protocols for NotchServiceProvider.
//  Plugins and views depend on the narrowest protocol they need.
//  ServiceContainer conforms to all sub-protocols via NotchServiceProvider.
//

import Foundation

// MARK: - Media Services

/// Music, lyrics, sound — for media-related plugins and views.
@MainActor
protocol MediaServiceProvider {
    var music: any MusicServiceProtocol { get }
    var lyrics: any LyricsServiceProtocol { get }
    var sound: any SoundServiceProtocol { get }
}

// MARK: - System Services

/// Volume, brightness, battery, keyboard backlight — system controls.
@MainActor
protocol SystemServiceProvider {
    var volume: any VolumeServiceProtocol { get }
    var brightness: any BrightnessServiceProtocol { get }
    var keyboardBacklight: any KeyboardBacklightServiceProtocol { get }
    var battery: any BatteryServiceProtocol { get }
    var xpcHelper: any XPCHelperServiceProtocol { get }
}

// MARK: - Storage Services

/// Shelf, temporary files, image processing, thumbnails — file management.
@MainActor
protocol StorageServiceProvider {
    var shelf: any ShelfServiceProtocol { get }
    var temporaryFileStorage: any TemporaryFileStorageServiceProtocol { get }
    var imageProcessing: any ImageProcessingServiceProtocol { get }
    var thumbnails: any ThumbnailServiceProtocol { get }
    var shelfImageProcessor: any ShelfImageProcessorProtocol { get }
    var shelfFileHandler: any ShelfFileHandlerProtocol { get }
    var quickLook: any QuickLookServiceProtocol { get }
    var quickShare: QuickShareService { get }
}

// MARK: - UI Services

/// Notifications, sharing, drag-drop, webcam — UI interaction services.
@MainActor
protocol UIServiceProvider {
    var notifications: any NotificationServiceProtocol { get }
    var systemNotificationObserver: any SystemNotificationObserverProtocol { get }
    var sharing: any SharingServiceProtocol { get }
    var dragDrop: any DragDropServiceProtocol { get }
    var webcam: any WebcamServiceProtocol { get }
    var face: any FaceServiceProtocol { get }
}

// MARK: - Plugin Services

/// API, AI, bluetooth, clipboard, notes — plugin-specific services.
@MainActor
protocol PluginExtensionServiceProvider {
    var apiRouteRegistrar: (any APIRouteRegistrar)? { get }
    var ai: any AITextGenerationService { get }
    var bluetooth: (any BluetoothServiceProtocol)? { get }
    var bluetoothManager: any BluetoothStateServiceProtocol { get }
    var notesManager: any NotesServiceProtocol { get }
    var clipboardManager: any ClipboardServiceProtocol { get }
    var calendar: any CalendarServiceProtocol { get }
    var weather: any WeatherServiceProtocol { get }
}
