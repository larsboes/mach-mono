import Foundation
import Combine
import AppKit
import SwiftUI

/// Protocol defining the music service capabilities
/// Note: Internal access since PlaybackState is internal
@MainActor
protocol MusicServiceProtocol: Observable {
    var playbackState: PlaybackState { get }
    var currentTrack: TrackInfo? { get }
    var artwork: NSImage? { get }
    var avgColor: NSColor { get }
    var progress: Double { get }
    var volume: Double { get }
    var isShuffled: Bool { get }
    var repeatMode: RepeatMode { get }
    var isFavorite: Bool { get }
    
    // Lyrics Support
    var currentLyrics: String { get }
    var isFetchingLyrics: Bool { get }
    var syncedLyrics: [(time: Double, text: String)] { get }
    
    // Advanced Playback Info
    var songDuration: TimeInterval { get }
    var elapsedTime: TimeInterval { get }
    var timestampDate: Date { get }
    var playbackRate: Double { get }
    var bundleIdentifier: String? { get }
    var canFavoriteTrack: Bool { get }
    var isPlayerIdle: Bool { get }
    var isNowPlayingDeprecated: Bool { get }
    var volumeControlSupported: Bool { get }
    
    // Actions
    func play() async
    func pause() async
    func togglePlayPause() async
    func next() async
    func previous() async
    func seek(to progress: Double) async
    func setVolume(_ volume: Double) async
    func toggleShuffle() async
    func toggleRepeat() async
    func toggleFavorite() async
    func openMusicApp() async
    func syncVolumeFromActiveApp() async
    func destroy()
    func forceUpdate()
    
    // Utilities
    func estimatedPlaybackPosition(at date: Date) -> TimeInterval

    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> { get }
    var sneakPeekPublisher: AnyPublisher<SneakPeekRequest, Never> { get }
}

/// Request to show a sneak peek
struct SneakPeekRequest: Equatable {
    let style: SneakPeekStyle
    let type: SneakContentType
    let value: CGFloat

    public init(style: SneakPeekStyle, type: SneakContentType, value: CGFloat = 0) {
        self.style = style
        self.type = type
        self.value = value
    }
}

/// Track information for music playback
struct TrackInfo: Equatable, Hashable, Codable, Sendable {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let artworkURL: URL?

    init(
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval = 0,
        artworkURL: URL? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkURL = artworkURL
    }

    /// Convenience initializer for simple cases (backwards compatible)
    init(title: String, artist: String, album: String) {
        self.init(title: title, artist: artist, album: album, duration: 0, artworkURL: nil)
    }
}
