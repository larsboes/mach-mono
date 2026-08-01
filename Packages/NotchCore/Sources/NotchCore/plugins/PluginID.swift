import Foundation

/// Centralized plugin identifiers — eliminates stringly-typed plugin references.
/// Each plugin's `id` property should return the corresponding constant.
public enum PluginID {
    public static let music = "com.machnotch.music"
    public static let shelf = "com.machnotch.shelf"
    public static let calendar = "com.machnotch.calendar"
    public static let weather = "com.machnotch.weather"
    public static let battery = "com.machnotch.battery"
    public static let webcam = "com.machnotch.webcam"
    public static let notifications = "com.machnotch.notifications"
    public static let clipboard = "com.machnotch.clipboard"
    public static let habitTracker = "com.machnotch.habittracker"
    public static let pomodoro = "com.machnotch.pomodoro"
    public static let teleprompter = "com.machnotch.teleprompter"
    public static let displaySurface = "com.machnotch.display-surface"
    public static let systemStats = "com.machnotch.system-stats"
    public static let brief = "com.machnotch.brief"
    public static let soundscape = "com.machnotch.soundscape"

    // System-level source IDs for events (not registered plugins)
    public enum System {
        public static let hud = "com.machnotch.system.hud"
        public static let volume = "com.machnotch.system.volume"
        public static let brightness = "com.machnotch.system.brightness"
        public static let backlight = "com.machnotch.system.backlight"
        public static let battery = "com.machnotch.system.battery"
        public static let keyboard = "com.machnotch.system.keyboard"
        public static let mediaKeys = "com.machnotch.system.mediakeys"
        public static let core = "com.machnotch.core"
    }
}
