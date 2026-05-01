import Foundation

/// Centralized plugin identifiers — eliminates stringly-typed plugin references.
/// Each plugin's `id` property should return the corresponding constant.
enum PluginID {
    static let music = "com.boringnotch.music"
    static let shelf = "com.boringnotch.shelf"
    static let calendar = "com.boringnotch.calendar"
    static let weather = "com.boringnotch.weather"
    static let battery = "com.boringnotch.battery"
    static let webcam = "com.boringnotch.webcam"
    static let notifications = "com.boringnotch.notifications"
    static let clipboard = "com.boringnotch.clipboard"
    static let habitTracker = "com.boringnotch.habittracker"
    static let pomodoro = "com.boringnotch.pomodoro"
    static let teleprompter = "com.boringnotch.teleprompter"
    static let displaySurface = "com.boringnotch.display-surface"

    // System-level source IDs for events (not registered plugins)
    enum System {
        static let hud = "com.boringnotch.system.hud"
        static let volume = "com.boringnotch.system.volume"
        static let brightness = "com.boringnotch.system.brightness"
        static let backlight = "com.boringnotch.system.backlight"
        static let battery = "com.boringnotch.system.battery"
        static let keyboard = "com.boringnotch.system.keyboard"
        static let mediaKeys = "com.boringnotch.system.mediakeys"
        static let core = "com.boringnotch.core"
    }
}
