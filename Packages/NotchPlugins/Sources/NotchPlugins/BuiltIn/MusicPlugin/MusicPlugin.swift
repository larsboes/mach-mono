//
//  MusicPlugin.swift
//  machNotch
//
//  Built-in music player plugin.
//  Wraps MusicService to provide playback controls in the notch.
//
//  Migration notes:
//  - This replaces direct MusicManager.shared access in views
//  - MusicManager becomes MusicService (implements MusicServiceProtocol)
//  - Views receive this plugin via @Environment(PluginManager.self)
//

import Combine
import SwiftUI

// MARK: - Music Plugin

@MainActor
@Observable
public final class MusicPlugin: NotchPlugin, PlayablePlugin, PositionedPlugin, ExportablePlugin {

    // MARK: - NotchPlugin

    public let id = PluginID.music

    public let metadata = PluginMetadata(
        name: "Music",
        description: "Control music playback from the notch",
        icon: "music.note",
        version: "1.0.0",
        author: "machNotch",
        category: .media
    )

    public var isEnabled: Bool = true

    public private(set) var state: PluginState = .inactive

    // MARK: - PlayablePlugin

    public var isPlaying: Bool {
        musicService?.playbackState.isPlaying ?? false
    }

    public var nowPlaying: NowPlayingInfo? {
        guard let service = musicService,
            let track = service.currentTrack
        else {
            return nil
        }
        return NowPlayingInfo(
            track: track,
            artwork: service.artwork,
            progress: service.progress,
            isPlaying: service.playbackState.isPlaying
        )
    }

    public var playbackProgress: Double {
        musicService?.progress ?? 0
    }

    // MARK: - PositionedPlugin

    public var closedNotchPosition: ClosedNotchPosition { .center }

    // MARK: - Private Properties

    public var musicService: (any MusicServiceProtocol)?
    private var settings: PluginSettings?
    private(set) var mediaSettings: (any MediaSettings)?
    private var eventBus: PluginEventBus?
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored private var activeTasks: [Task<Void, Never>] = []

    // Audio pipeline — backing storage for MusicPlugin+AudioPipeline.swift
    var audioCaptureService: (any AudioCaptureServiceProtocol)?
    var fftProcessor: AudioFFTProcessor?
    public var frequencyBands: [Float] = []
    public var peakBands: [Float] = []

    // Plugin-specific settings
    private var showLyrics: Bool = true
    private var enableSneakPeek: Bool = true
    private var sneakPeekDuration: TimeInterval = 3.0

    // MARK: - Initialization

    public init() {}

    // MARK: - Lifecycle

    public func activate(context: PluginContext) async throws {
        state = .activating

        // Store references
        self.musicService = context.mediaServices.music
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
            activeTasks.append(Task { await self.startAudioCapture() })
        }

        state = .active
    }

    // Synchronous cancel for test teardown — avoids async tearDown which crashes
    // in XCTest on macOS 26 beta (XCTFailableInvocation / _observeErrors bug).
    public func deactivate_cancelOnly() {
        cancellables.removeAll()
        activeTasks.forEach { $0.cancel() }
        activeTasks.removeAll()
        state = .inactive
    }

    public func deactivate() async {
        // Cancel subscriptions first so no new tasks can be enqueued.
        cancellables.removeAll()
        // Capture, clear, cancel, then await — ensures no pending tasks remain
        // when XCTest's teardown machinery runs (prevents task-local storage
        // deallocation order violations on macOS 26).
        let tasks = activeTasks
        activeTasks.removeAll()
        tasks.forEach { $0.cancel() }
        for task in tasks { _ = await task.value }
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

    public func play() async {
        await musicService?.play()
    }

    public func pause() async {
        await musicService?.pause()
    }

    public func next() async {
        await musicService?.next()
    }

    public func previous() async {
        await musicService?.previous()
    }

    public func seek(to progress: Double) async {
        await musicService?.seek(to: progress)
    }

    // MARK: - UI Slots

    public var displayRequest: DisplayRequest? {
        guard isEnabled, state.isActive,
            let service = musicService,
            service.playbackState.isPlaying || !service.isPlayerIdle,
            settings?.get("showLiveActivity", default: true) ?? true
        else {
            return nil
        }
        return DisplayRequest(priority: .high, category: DisplayRequest.music)
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
            .sink { [weak self] playbackState in
                guard let self = self else { return }
                let event = MusicPlaybackChangedEvent(
                    isPlaying: playbackState.isPlaying,
                    track: self.musicService?.currentTrack
                )
                self.eventBus?.emit(event)
                // Only drive audio capture when the visualizer is enabled.
                // Guards against no-op task creation (e.g. in tests where ambientVisualizerEnabled
                // is false) which avoids XCTest macOS 26 beta _swift_task_dealloc_specific crashes
                // caused by unstructured tasks outliving async setUp/_observeErrors contexts.
                guard let ms = self.mediaSettings, ms.ambientVisualizerEnabled else { return }
                let t = Task.detached { @MainActor [weak self] in
                    guard !Task.isCancelled, let self else { return }
                    if playbackState.isPlaying {
                        await self.startAudioCapture()
                    } else {
                        await self.stopAudioCapture()
                    }
                }
                self.activeTasks.append(t)
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
