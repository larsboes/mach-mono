import Foundation
import Combine
import AppKit
import SwiftUI

/// Concrete implementation of MusicService wrapping MusicManager
@MainActor
@Observable
final class MusicService: MusicServiceProtocol {
    // MARK: - Properties

    var playbackState: PlaybackState = PlaybackState(bundleIdentifier: "")
    var currentTrack: TrackInfo?
    var artwork: NSImage?
    var avgColor: NSColor = .gray
    var progress: Double = 0
    var volume: Double = 0.5
    var isShuffled: Bool = false
    var repeatMode: RepeatMode = .off
    var isFavorite: Bool = false

    // MARK: - Advanced Properties (Delegated)
    
    var currentLyrics: String { manager.currentLyrics }
    var isFetchingLyrics: Bool { manager.isFetchingLyrics }
    var syncedLyrics: [(time: Double, text: String)] { manager.syncedLyrics }
    
    var songDuration: TimeInterval { manager.songDuration }
    var elapsedTime: TimeInterval { manager.elapsedTime }
    var timestampDate: Date { manager.timestampDate }
    var playbackRate: Double { manager.playbackRate }
    var bundleIdentifier: String? { manager.bundleIdentifier }
    var canFavoriteTrack: Bool { manager.canFavoriteTrack }
    var isPlayerIdle: Bool { manager.isPlayerIdle }
    var isNowPlayingDeprecated: Bool { manager.isNowPlayingDeprecated }
    var volumeControlSupported: Bool { manager.volumeControlSupported }

    private let manager: MusicManager
    private var cancellables = Set<AnyCancellable>()

    // Publisher for the protocol
    private let _playbackStateSubject = PassthroughSubject<PlaybackState, Never>()
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        _playbackStateSubject.eraseToAnyPublisher()
    }
    
    var sneakPeekPublisher: AnyPublisher<SneakPeekRequest, Never> {
        manager.sneakPeekPublisher
    }

    // MARK: - Initialization

    init(manager: MusicManager) {
        self.manager = manager
        setupSubscriptions()

        // Initial state
        self.artwork = manager.albumArt
        self.currentTrack = TrackInfo(
            title: manager.songTitle,
            artist: manager.artistName,
            album: manager.album
        )
        self.volume = manager.volume
        self.isShuffled = manager.isShuffled
        self.repeatMode = manager.repeatMode
        self.isFavorite = manager.isFavoriteTrack
        
        // Note: We don't have full playback state initially unless we force update or wait for first event
        manager.forceUpdate()
    }

    private func setupSubscriptions() {
        manager.playbackStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateState(state)
            }
            .store(in: &cancellables)

        manager.avgColorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] color in
                self?.avgColor = color
            }
            .store(in: &cancellables)
    }

    private func updateState(_ state: PlaybackState) {
        self.playbackState = state
        self.currentTrack = TrackInfo(
            title: state.title,
            artist: state.artist,
            album: state.album
        )

        if let data = state.artwork, let image = NSImage(data: data) {
            self.artwork = image
        } else {
            // Use the image from MusicManager if state doesn't have it,
            // because MusicManager handles App Icon fallback.
            self.artwork = manager.albumArt
        }

        let songDuration = manager.songDuration
        self.progress = songDuration > 0 ? manager.elapsedTime / songDuration : 0
        self.volume = state.volume
        self.isShuffled = state.isShuffled
        self.repeatMode = state.repeatMode
        self.isFavorite = state.isFavorite

        _playbackStateSubject.send(state)
    }

    // MARK: - Controls

    func play() async {
        manager.play()
    }

    func pause() async {
        manager.pause()
    }

    func togglePlayPause() async {
        manager.togglePlay()
    }

    func next() async {
        manager.nextTrack()
    }

    func previous() async {
        manager.previousTrack()
    }

    func seek(to progress: Double) async {
        let songDuration = manager.songDuration
        let time = songDuration * progress
        manager.seek(to: time)
    }

    func setVolume(_ volume: Double) async {
        manager.setVolume(to: volume)
    }

    func toggleShuffle() async {
        manager.toggleShuffle()
    }

    func toggleRepeat() async {
        manager.toggleRepeat()
    }

    func toggleFavorite() async {
        manager.toggleFavoriteTrack()
    }
    
    func openMusicApp() async {
        manager.openMusicApp()
    }
    
    func syncVolumeFromActiveApp() async {
        await manager.syncVolumeFromActiveApp()
    }
    
    func destroy() {
        manager.destroy()
    }
    
    func forceUpdate() {
        manager.forceUpdate()
    }
    
    func estimatedPlaybackPosition(at date: Date) -> TimeInterval {
        manager.estimatedPlaybackPosition(at: date)
    }
}
