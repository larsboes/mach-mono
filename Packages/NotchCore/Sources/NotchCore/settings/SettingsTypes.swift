import Defaults
import Foundation

public enum CalendarSelectionState: Codable, Defaults.Serializable, Sendable {
    case all
    case selected(Set<String>)
}

public enum HideNotchOption: String, Defaults.Serializable {
    case always
    case nowPlayingOnly
    case never
}

public enum MediaControllerType: String, CaseIterable, Identifiable, Defaults.Serializable {
    case nowPlaying = "Now Playing"
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case youtubeMusic = "YouTube Music"
    case browser = "Browser"
    public var id: String { self.rawValue }

    public static func availableControllers(isNowPlayingDeprecated: Bool) -> [MediaControllerType] {
        guard isNowPlayingDeprecated else { return allCases }
        return allCases.filter { $0 != .nowPlaying }
    }

    public static func defaultController(isNowPlayingDeprecated: Bool) -> MediaControllerType {
        isNowPlayingDeprecated ? .appleMusic : .nowPlaying
    }
}

public enum WeatherSource: String, CaseIterable, Identifiable, Defaults.Serializable {
    case auto = "Auto"
    case weatherKit = "Native WeatherKit"
    case openWeatherMap = "OpenWeatherMap"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .auto:
            return "Use OpenWeatherMap as the primary source; WeatherKit is only a fallback when available."
        case .weatherKit:
            return "Use Apple's native WeatherKit data. Requires the WeatherKit entitlement."
        case .openWeatherMap:
            return "Use your OpenWeatherMap API key."
        }
    }
}

public enum SneakPeekStyle: String, CaseIterable, Identifiable, Defaults.Serializable, Sendable {
    case standard = "Default"
    case inline = "Inline"
    case minimal = "Minimal"
    case expanding = "Expanding"
    public var id: String { self.rawValue }
    public static let selectableCases: [SneakPeekStyle] = [.standard, .inline, .minimal]
}

public enum OptionKeyAction: String, CaseIterable, Identifiable, Defaults.Serializable {
    case openSettings = "Open System Settings"
    case showHUD = "Show HUD"
    case none = "No Action"
    public var id: String { self.rawValue }
}

public enum Mood: String, Codable, CaseIterable, Defaults.Serializable {
    case happy, neutral, sad, surprised, angry, sleepy
}

public enum LiquidGlassStyle: String, CaseIterable, Identifiable, Codable, Defaults.Serializable {
    case `default` = "Default"
    case subtle = "Subtle"
    case vibrant = "Vibrant"
    public var id: String { rawValue }
}

public enum NotificationDeliveryStyle: String, CaseIterable, Defaults.Serializable {
    case banner
    case soundOnly
    public var localizedName: String {
        switch self {
        case .banner: return "Banner & Sound"
        case .soundOnly: return "Sound Only"
        }
    }
}

public enum AmbientVisualizerMode: String, CaseIterable, Identifiable, Defaults.Serializable {
    case simulated = "simulated"
    case realAudio = "realAudio"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .simulated: return "Generative"
        case .realAudio: return "Audio Reactive"
        }
    }

    public var icon: String {
        switch self {
        case .simulated: return "wand.and.stars"
        case .realAudio: return "waveform.path.ecg"
        }
    }
}

public enum VisualizerBandCount: Int, CaseIterable, Identifiable, Defaults.Serializable {
    case sixteen = 16
    case thirtyTwo = 32
    case sixtyFour = 64

    public var id: Int { rawValue }
    public var displayName: String { "\(rawValue) bands" }
}

public struct BluetoothDeviceIconMapping: Codable, Defaults.Serializable {
    public let UUID: UUID
    public let deviceName: String
    public var sfSymbolName: String

    public init(UUID: Foundation.UUID = Foundation.UUID(), deviceName: String, sfSymbolName: String) {
        self.UUID = UUID
        self.deviceName = deviceName
        self.sfSymbolName = sfSymbolName
    }
}
