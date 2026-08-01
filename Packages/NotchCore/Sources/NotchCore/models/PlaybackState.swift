import Foundation

public enum RepeatMode: Int, Codable {
    case off = 1
    case one = 2
    case all = 3
}

public struct PlaybackState: Equatable {
    public var bundleIdentifier: String
    public var isPlaying: Bool
    public var title: String
    public var artist: String
    public var album: String
    public var playbackRate: Double
    public var isShuffled: Bool
    public var repeatMode: RepeatMode
    public var lastUpdated: Date
    public var artwork: Data?
    public var volume: Double
    public var isFavorite: Bool

    public init(
        bundleIdentifier: String,
        isPlaying: Bool = false,
        title: String = "I'm Handsome",
        artist: String = "Me",
        album: String = "Self Love",
        playbackRate: Double = 1,
        isShuffled: Bool = false,
        repeatMode: RepeatMode = .off,
        lastUpdated: Date = Date.distantPast,
        artwork: Data? = nil,
        volume: Double = 0.5,
        isFavorite: Bool = false
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.isPlaying = isPlaying
        self.title = title
        self.artist = artist
        self.album = album
        self.playbackRate = playbackRate
        self.isShuffled = isShuffled
        self.repeatMode = repeatMode
        self.lastUpdated = lastUpdated
        self.artwork = artwork
        self.volume = volume
        self.isFavorite = isFavorite
    }

    public static func == (lhs: PlaybackState, rhs: PlaybackState) -> Bool {
        return lhs.bundleIdentifier == rhs.bundleIdentifier
            && lhs.isPlaying == rhs.isPlaying
            && lhs.title == rhs.title
            && lhs.artist == rhs.artist
            && lhs.album == rhs.album
            && lhs.isShuffled == rhs.isShuffled
            && lhs.repeatMode == rhs.repeatMode
            && lhs.artwork == rhs.artwork
            && lhs.isFavorite == rhs.isFavorite
            && lhs.lastUpdated == rhs.lastUpdated
    }
}
