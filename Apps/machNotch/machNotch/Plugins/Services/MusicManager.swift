//
//  MusicManager.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 03/08/24.
//
//  Thin facade composing MusicPlaybackController, MusicArtworkService,
//  and LyricsService. Delegates all work to sub-services.
//

import AppKit
import Combine
import SwiftUI

@MainActor
@Observable
final class MusicManager {
    // MARK: - Sub-services

    private let playback: MusicPlaybackController
    private let artwork: MusicArtworkService
    private let _lyricsService = LyricsService()
    private let settings: any MediaSettings

    // MARK: - Forwarded Properties (Playback)

    var songTitle: String { playback.songTitle }
    var artistName: String { playback.artistName }
    var album: String { playback.album }
    var isPlaying: Bool { playback.isPlaying }
    var isPlayerIdle: Bool { playback.isPlayerIdle }
    var bundleIdentifier: String? { playback.bundleIdentifier }
    var songDuration: TimeInterval { playback.songDuration }
    var elapsedTime: TimeInterval { playback.elapsedTime }
    var timestampDate: Date { playback.timestampDate }
    var playbackRate: Double { playback.playbackRate }
    var isShuffled: Bool { playback.isShuffled }
    var repeatMode: RepeatMode { playback.repeatMode }
    var volume: Double { playback.volume }
    var volumeControlSupported: Bool { playback.volumeControlSupported }
    var canFavoriteTrack: Bool { playback.canFavoriteTrack }
    var isFavoriteTrack: Bool { playback.isFavoriteTrack }
    var isNowPlayingDeprecated: Bool { playback.isNowPlayingDeprecated }

    // MARK: - Forwarded Properties (Artwork)

    var albumArt: NSImage { artwork.albumArt }
    var avgColor: NSColor { artwork.avgColor }
    var usingAppIconForArtwork: Bool { artwork.usingAppIconForArtwork }
    var isFlipping: Bool { artwork.isFlipping }

    // MARK: - Forwarded Properties (Lyrics)

    var lyricsService: LyricsService { _lyricsService }
    var currentLyrics: String { _lyricsService.currentLyrics }
    var isFetchingLyrics: Bool { _lyricsService.isFetchingLyrics }
    var syncedLyrics: [(time: Double, text: String)] { _lyricsService.syncedLyrics }

    // MARK: - Publishers

    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        playback.playbackStatePublisher
    }

    var avgColorPublisher: AnyPublisher<NSColor, Never> {
        artwork.avgColorPublisher
    }

    var sneakPeekPublisher: AnyPublisher<SneakPeekRequest, Never> {
        playback.sneakPeekPublisher
    }

    // MARK: - Initialization

    init(settings: any MediaSettings) {
        self.settings = settings
        self.artwork = MusicArtworkService(settings: settings)
        self.playback = MusicPlaybackController(settings: settings)

        // Wire artwork updates from playback state changes
        playback.onContentChange = { [weak self] state in
            guard let self = self else { return }
            self.artwork.handleContentChange(state)
            self.fetchLyricsIfAvailable(
                bundleIdentifier: state.bundleIdentifier,
                title: state.title,
                artist: state.artist
            )
        }
    }

    func destroy() {
        playback.destroy()
        artwork.destroy()
    }

    // MARK: - Transport Controls

    func playPause() { playback.playPause() }
    func play() { playback.play() }
    func pause() { playback.pause() }
    func togglePlay() { playback.togglePlay() }
    func nextTrack() { playback.nextTrack() }
    func previousTrack() { playback.previousTrack() }
    func seek(to position: TimeInterval) { playback.seek(to: position) }
    func skip(seconds: TimeInterval) { playback.skip(seconds: seconds) }
    func toggleShuffle() { playback.toggleShuffle() }
    func toggleRepeat() { playback.toggleRepeat() }
    func setVolume(to level: Double) { playback.setVolume(to: level) }
    func openMusicApp() { playback.openMusicApp() }
    func forceUpdate() { playback.forceUpdate() }

    func syncVolumeFromActiveApp() async {
        await playback.syncVolumeFromActiveApp()
    }

    func toggleFavoriteTrack() { playback.toggleFavoriteTrack() }
    func setFavorite(_ favorite: Bool) { playback.setFavorite(favorite) }
    func dislikeCurrentTrack() { playback.setFavorite(false) }

    // MARK: - Playback Position

    func estimatedPlaybackPosition(at date: Date = Date()) -> TimeInterval {
        playback.estimatedPlaybackPosition(at: date)
    }

    // MARK: - Lyrics

    private func fetchLyricsIfAvailable(bundleIdentifier: String?, title: String, artist: String) {
        guard settings.enableLyrics, !title.isEmpty else {
            Task { @MainActor in
                _lyricsService.clearLyrics()
            }
            return
        }

        Task { @MainActor in
            await _lyricsService.fetchLyrics(
                bundleIdentifier: bundleIdentifier,
                title: title,
                artist: artist
            )
        }
    }
}
