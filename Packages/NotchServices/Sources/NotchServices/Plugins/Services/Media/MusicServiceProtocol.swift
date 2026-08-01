import AppKit
import Combine
import Foundation
import SwiftUI

/// Protocol defining the music service capabilities
/// Note: Internal access since PlaybackState is internal
@MainActor
public protocol MusicServiceProtocol: Observable {
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
public struct SneakPeekRequest: Equatable, Sendable {
    public let style: SneakPeekStyle
    public let type: SneakContentType
    public let value: CGFloat

    public init(style: SneakPeekStyle, type: SneakContentType, value: CGFloat = 0) {
        self.style = style
        self.type = type
        self.value = value
    }
}

/// Track information for music playback
public struct TrackInfo: Equatable, Hashable, Codable, Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let duration: TimeInterval
    public let artworkURL: URL?

    public init(
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
    public init(title: String, artist: String, album: String) {
        self.init(title: title, artist: artist, album: album, duration: 0, artworkURL: nil)
    }
}
