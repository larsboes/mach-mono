//
//  MusicPlugin.swift
//  boringNotch
//
//  Built-in music player plugin.
//  Wraps MusicService to provide playback controls in the notch.
//
//  Migration notes:
//  - This replaces direct MusicManager.shared access in views
//  - MusicManager becomes MusicService (implements MusicServiceProtocol)
//  - Views receive this plugin via @Environment(PluginManager.self)
//

import SwiftUI
import Combine

// MARK: - Music Plugin

@MainActor
@Observable
final class MusicPlugin: NotchPlugin, PlayablePlugin, PositionedPlugin, ExportablePlugin {

    // MARK: - NotchPlugin

    let id = PluginID.music

    let metadata = PluginMetadata(
        name: "Music",
        description: "Control music playback from the notch",
        icon: "music.note",
        version: "1.0.0",
        author: "boringNotch",
        category: .media
    )

    var isEnabled: Bool = true

    private(set) var state: PluginState = .inactive

    // MARK: - PlayablePlugin

    var isPlaying: Bool {
        musicService?.playbackState.isPlaying ?? false
    }

    var nowPlaying: NowPlayingInfo? {
        guard let service = musicService,
              let track = service.currentTrack else {
            return nil
        }
        return NowPlayingInfo(
            track: track,
            artwork: service.artwork,
            progress: service.progress,
            isPlaying: service.playbackState.isPlaying
        )
    }

    var playbackProgress: Double {
        musicService?.progress ?? 0
    }

    // MARK: - PositionedPlugin

    var closedNotchPosition: ClosedNotchPosition { .center }

    // MARK: - Private Properties

    var musicService: (any MusicServiceProtocol)?
    private var settings: PluginSettings?
    private(set) var mediaSettings: (any MediaSettings)?
    private var eventBus: PluginEventBus?
    private var cancellables = Set<AnyCancellable>()

    // Audio pipeline — backing storage for MusicPlugin+AudioPipeline.swift
    var audioCaptureService: (any AudioCaptureServiceProtocol)?
    var fftProcessor: AudioFFTProcessor?
    var frequencyBands: [Float] = []
    var peakBands: [Float] = []

    // Plugin-specific settings
    private var showLyrics: Bool = true
    private var enableSneakPeek: Bool = true
    private var sneakPeekDuration: TimeInterval = 3.0

    // MARK: - Initialization

    init() {}

    // MARK: - Lifecycle

    func activate(context: PluginContext) async throws {
        state = .activating

        // Store references
        self.musicService = context.services.music
        self.settings = context.settings
        self.mediaSettings = context.mediaSettings
        self.eventBus = context.eventBus

        // Load settings
        loadSettings()

        // Subscribe to playback changes
        setupSubscriptions()

        // Set up audio FFT pipeline
        setupAudioPipeline()

        // Start capture immediately if music is already playing
        if musicService?.playbackState.isPlaying == true {
            Task { await startAudioCapture() }
        }

        state = .active
    }

    func deactivate() async {
        cancellables.removeAll()
        await stopAudioCapture()
        audioCaptureService = nil
        fftProcessor = nil
        musicService = nil
        settings = nil
        mediaSettings = nil
        eventBus = nil
        state = .inactive
    }

    // MARK: - Playback Controls

    func play() async {
        await musicService?.play()
    }

    func pause() async {
        await musicService?.pause()
    }

    func next() async {
        await musicService?.next()
    }

    func previous() async {
        await musicService?.previous()
    }

    func seek(to progress: Double) async {
        await musicService?.seek(to: progress)
    }

    // MARK: - UI Slots

    var displayRequest: DisplayRequest? {
        guard isEnabled, state.isActive,
              let service = musicService,
              service.playbackState.isPlaying || !service.isPlayerIdle,
              // Use settings to check if Live Activity is enabled
              settings?.get("showLiveActivity", default: true) ?? true
        else {
            return nil
        }

        return DisplayRequest(priority: .high, category: DisplayRequest.music)
    }

    @ViewBuilder
    func closedNotchContent() -> some View {
        if isEnabled, state.isActive, let service = musicService {
            MusicLiveActivity(service: service, frequencyBands: frequencyBands)
        }
    }

    @ViewBuilder
    func expandedPanelContent() -> some View {
        if isEnabled, state.isActive {
            MusicExpandedViewWrapper(plugin: self)
        }
    }

    @ViewBuilder
    func settingsContent() -> some View {
        MusicSettingsView(plugin: self)
    }

    @ViewBuilder
    func menuBarView() -> some View {
        if isEnabled, state.isActive, let info = nowPlaying {
            Section(info.track.title) {
                Text(info.track.artist)
            }
            Button(info.isPlaying ? "Pause" : "Play") {
                Task { await self.togglePlayPause() }
            }
            Button("Next Track") {
                Task { await self.next() }
            }
        }
    }

    // MARK: - ExportablePlugin

    var supportedExportFormats: [ExportFormat] { [.json] }

    func exportData(format: ExportFormat) async throws -> Data {
        guard format == .json else {
            throw PluginError.exportFailed("Unsupported format: \(format.displayName)")
        }
        guard let service = musicService else {
            throw PluginError.exportFailed("Music service unavailable")
        }
        let snapshot = MusicExportSnapshot(
            track: service.currentTrack,
            isPlaying: service.playbackState.isPlaying,
            progress: service.progress,
            volume: service.volume,
            isShuffled: service.isShuffled,
            exportedAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    // MARK: - Private Methods

    private func loadSettings() {
        guard let settings = settings else { return }

        showLyrics = settings.get("showLyrics", default: true)
        enableSneakPeek = settings.get("enableSneakPeek", default: true)
        sneakPeekDuration = settings.get("sneakPeekDuration", default: 3.0)
    }

    private func setupSubscriptions() {
        guard let service = musicService else { return }

        // Emit events when playback state changes + drive audio capture.
        // Prepend current state so capture starts immediately if music is already playing.
        service.playbackStatePublisher
            .prepend(service.playbackState)
            .sink { [weak self] playbackState in
                guard let self = self else { return }
                let event = MusicPlaybackChangedEvent(
                    isPlaying: playbackState.isPlaying,
                    track: self.musicService?.currentTrack
                )
                self.eventBus?.emit(event)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if playbackState.isPlaying {
                        await self.startAudioCapture()
                    } else {
                        await self.stopAudioCapture()
                    }
                }
            }
            .store(in: &cancellables)
            
        // Emit events when sneak peek is requested
        service.sneakPeekPublisher
            .sink { [weak self] request in
                guard let self = self else { return }
                let event = SneakPeekRequestedEvent(
                    sourcePluginId: self.id,
                    request: request
                )
                self.eventBus?.emit(event)
            }
            .store(in: &cancellables)
    }
}

// MARK: - Export DTO

private struct MusicExportSnapshot: Codable {
    let track: TrackInfo?
    let isPlaying: Bool
    let progress: Double
    let volume: Double
    let isShuffled: Bool
    let exportedAt: Date
}

// MARK: - View Wrappers

struct MusicExpandedViewWrapper: View {
    let plugin: MusicPlugin
    @Environment(\.albumArtNamespace) var namespace: Namespace.ID?

    var body: some View {
        PluginMusicPlayerView(plugin: plugin, albumArtNamespace: namespace)
    }
}
