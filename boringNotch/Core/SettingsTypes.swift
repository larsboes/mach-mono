//
//  SettingsTypes.swift
//  boringNotch
//
//  Settings value types — all Defaults.Serializable enums used in user preferences.
//

import SwiftUI
import Defaults

enum CalendarSelectionState: Codable, Defaults.Serializable, Sendable {
    case all
    case selected(Set<String>)
}

enum HideNotchOption: String, Defaults.Serializable {
    case always
    case nowPlayingOnly
    case never
}

enum MediaControllerType: String, CaseIterable, Identifiable, Defaults.Serializable {
    case nowPlaying = "Now Playing"
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case youtubeMusic = "YouTube Music"
    var id: String { self.rawValue }
}

enum SneakPeekStyle: String, CaseIterable, Identifiable, Defaults.Serializable {
    case standard = "Default"
    case inline = "Inline"
    case minimal = "Minimal"
    case expanding = "Expanding"
    var id: String { self.rawValue }
    static let selectableCases: [SneakPeekStyle] = [.standard, .inline, .minimal]
}

enum OptionKeyAction: String, CaseIterable, Identifiable, Defaults.Serializable {
    case openSettings = "Open System Settings"
    case showHUD = "Show HUD"
    case none = "No Action"
    var id: String { self.rawValue }
}

enum Mood: String, Codable, CaseIterable, Defaults.Serializable {
    case happy, neutral, sad, surprised, angry, sleepy
}

enum LiquidGlassStyle: String, CaseIterable, Identifiable, Codable, Defaults.Serializable {
    case `default` = "Default"
    case subtle = "Subtle"
    case vibrant = "Vibrant"
    var id: String { rawValue }
    var configuration: LiquidGlassConfiguration {
        switch self {
        case .default: return .default
        case .subtle: return .subtle
        case .vibrant: return .vibrant
        }
    }
}

enum NotificationDeliveryStyle: String, CaseIterable, Defaults.Serializable {
    case banner
    case soundOnly
    var localizedName: String {
        switch self {
        case .banner: return "Banner & Sound"
        case .soundOnly: return "Sound Only"
        }
    }
}

enum AmbientVisualizerMode: String, CaseIterable, Identifiable, Defaults.Serializable {
    case simulated = "simulated"
    case realAudio = "realAudio"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simulated: return "Generative"
        case .realAudio: return "Audio Reactive"
        }
    }

    var icon: String {
        switch self {
        case .simulated: return "wand.and.stars"
        case .realAudio: return "waveform.path.ecg"
        }
    }
}

enum VisualizerBandCount: Int, CaseIterable, Identifiable, Defaults.Serializable {
    case sixteen = 16
    case thirtyTwo = 32
    case sixtyFour = 64

    var id: Int { rawValue }
    var displayName: String { "\(rawValue) bands" }
}
