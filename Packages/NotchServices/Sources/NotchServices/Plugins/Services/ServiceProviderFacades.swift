//
//  ServiceProviderFacades.swift
//  machNotch
//
//  Capability facades handed to plugins through PluginContext.
//
//  Each facade conforms to exactly one sub-protocol of NotchServiceProvider and
//  forwards to the real container. That is the point: ServiceContainer conforms
//  to every sub-protocol, so handing a plugin the container typed as
//  `any MediaServiceProvider` lets it cast back up to NotchServiceProvider and
//  reach clipboard, calendar and webcam it never declared. A facade cannot be
//  cast up, because it does not conform to the other sub-protocols.
//

import Foundation
import MachIntelligenceKit

@MainActor
public struct MediaServiceFacade: MediaServiceProvider {
    private let base: any MediaServiceProvider
    public init(_ base: any MediaServiceProvider) { self.base = base }

    public var music: any MusicServiceProtocol { base.music }
    public var lyrics: any LyricsServiceProtocol { base.lyrics }
    public var sound: any SoundServiceProtocol { base.sound }
}

@MainActor
public struct SystemServiceFacade: SystemServiceProvider {
    private let base: any SystemServiceProvider
    public init(_ base: any SystemServiceProvider) { self.base = base }

    public var volume: any VolumeServiceProtocol { base.volume }
    public var brightness: any BrightnessServiceProtocol { base.brightness }
    public var keyboardBacklight: any KeyboardBacklightServiceProtocol { base.keyboardBacklight }
    public var battery: any BatteryServiceProtocol { base.battery }
    public var systemStats: any SystemStatsServiceProtocol { base.systemStats }
    public var xpcHelper: any XPCHelperServiceProtocol { base.xpcHelper }
    public var fullScreen: any FullScreenServiceProtocol { base.fullScreen }
}

@MainActor
public struct StorageServiceFacade: StorageServiceProvider {
    private let base: any StorageServiceProvider
    public init(_ base: any StorageServiceProvider) { self.base = base }

    public var shelf: any ShelfServiceProtocol { base.shelf }
    public var temporaryFileStorage: any TemporaryFileStorageServiceProtocol { base.temporaryFileStorage }
    public var imageProcessing: any ImageProcessingServiceProtocol { base.imageProcessing }
    public var thumbnails: any ThumbnailServiceProtocol { base.thumbnails }
    public var shelfImageProcessor: any ShelfImageProcessorProtocol { base.shelfImageProcessor }
    public var shelfFileHandler: any ShelfFileHandlerProtocol { base.shelfFileHandler }
    public var quickLook: any QuickLookServiceProtocol { base.quickLook }
    public var quickShare: QuickShareService { base.quickShare }
}

@MainActor
public struct UIServiceFacade: UIServiceProvider {
    private let base: any UIServiceProvider
    public init(_ base: any UIServiceProvider) { self.base = base }

    public var notifications: any NotificationServiceProtocol { base.notifications }
    public var systemNotificationObserver: any SystemNotificationObserverProtocol {
        base.systemNotificationObserver
    }
    public var sharing: any SharingServiceProtocol { base.sharing }
    public var dragDrop: any DragDropServiceProtocol { base.dragDrop }
    public var webcam: any WebcamServiceProtocol { base.webcam }
    public var face: any FaceServiceProtocol { base.face }
}

@MainActor
public struct PluginExtensionServiceFacade: PluginExtensionServiceProvider {
    private let base: any PluginExtensionServiceProvider
    public init(_ base: any PluginExtensionServiceProvider) { self.base = base }

    public var apiRouteRegistrar: (any APIRouteRegistrar)? { base.apiRouteRegistrar }
    public var ai: any AITextGenerationService { base.ai }
    public var aiEmbedding: any AIEmbeddingService { base.aiEmbedding }
    public var bluetooth: (any BluetoothServiceProtocol)? { base.bluetooth }
    public var bluetoothManager: any BluetoothStateServiceProtocol { base.bluetoothManager }
    public var notesManager: any NotesServiceProtocol { base.notesManager }
    public var clipboardManager: any ClipboardServiceProtocol { base.clipboardManager }
    public var calendar: any CalendarServiceProtocol { base.calendar }
    public var weather: any WeatherServiceProtocol { base.weather }
}
