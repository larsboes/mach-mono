//
//  generic.swift
//  machNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Defaults
import Foundation

public enum Style {
    case notch
    case floating
}

public enum ContentType: Int, Codable, Hashable, Equatable {
    case normal
    case menu
    case settings
}

public enum NotchState {
    case closed
    case open
}

public struct NotchViews: Sendable, Hashable, Equatable {
    public let id: String

    public init(id: String) {
        self.id = id
    }

    public static let home = NotchViews(id: "home")
    public static let shelf = NotchViews(id: PluginID.shelf)
    public static let notifications = NotchViews(id: PluginID.notifications)
    public static let clipboard = NotchViews(id: PluginID.clipboard)
    public static let notes = NotchViews(id: "notes")  // Legacy manual notes plugin mapping
    public static let habitTracker = NotchViews(id: PluginID.habitTracker)
    public static let pomodoro = NotchViews(id: PluginID.pomodoro)
    public static let teleprompter = NotchViews(id: PluginID.teleprompter)
    public static let weather = NotchViews(id: PluginID.weather)
    public static let systemStats = NotchViews(id: PluginID.systemStats)
    public static let brief = NotchViews(id: PluginID.brief)

    public static func plugin(_ id: String) -> NotchViews {
        return NotchViews(id: id)
    }
}

enum SettingsEnum {
    case general
    case about
    case charge
    case download
    case mediaPlayback
    case hud
    case shelf
    case extensions
}

enum DownloadIndicatorStyle: String, Defaults.Serializable {
    case progress = "Progress"
    case percentage = "Percentage"
}

enum DownloadIconStyle: String, Defaults.Serializable {
    case onlyAppIcon = "Only app icon"
    case onlyIcon = "Only download icon"
    case iconAndAppIcon = "Icon and app icon"
}

enum MirrorShapeEnum: String, Defaults.Serializable {
    case rectangle = "Rectangular"
    case circle = "Circular"
}

enum WindowHeightMode: String, Defaults.Serializable {
    case matchMenuBar = "Match menubar height"
    case matchRealNotchSize = "Match real notch height"
    case custom = "Custom height"
}

enum SliderColorEnum: String, CaseIterable, Defaults.Serializable {
    case white = "White"
    case albumArt = "Match album art"
    case accent = "Accent color"
}
