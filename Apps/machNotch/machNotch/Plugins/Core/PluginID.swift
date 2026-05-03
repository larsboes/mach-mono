import Foundation

/// Centralized plugin identifiers — eliminates stringly-typed plugin references.
/// Each plugin's `id` property should return the corresponding constant.
enum PluginID {
    static let music = "com.machnotch.music"
    static let shelf = "com.machnotch.shelf"
    static let calendar = "com.machnotch.calendar"
    static let weather = "com.machnotch.weather"
    static let battery = "com.machnotch.battery"
    static let webcam = "com.machnotch.webcam"
    static let notifications = "com.machnotch.notifications"
    static let clipboard = "com.machnotch.clipboard"
    static let habitTracker = "com.machnotch.habittracker"
    static let pomodoro = "com.machnotch.pomodoro"
    static let teleprompter = "com.machnotch.teleprompter"
    static let displaySurface = "com.machnotch.display-surface"
    static let systemStats = "com.machnotch.system-stats"

    // System-level source IDs for events (not registered plugins)
    enum System {
        static let hud = "com.machnotch.system.hud"
        static let volume = "com.machnotch.system.volume"
        static let brightness = "com.machnotch.system.brightness"
        static let backlight = "com.machnotch.system.backlight"
        static let battery = "com.machnotch.system.battery"
        static let keyboard = "com.machnotch.system.keyboard"
        static let mediaKeys = "com.machnotch.system.mediakeys"
        static let core = "com.machnotch.core"
    }
}
