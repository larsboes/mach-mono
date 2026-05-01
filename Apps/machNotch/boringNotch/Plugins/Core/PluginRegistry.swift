//
//  PluginRegistry.swift
//  boringNotch
//
//  Single place to declare built-in plugins.
//  AppObjectGraph reads this list — add new plugins here without touching AppObjectGraph.
//

import Foundation

@MainActor
enum PluginRegistry {
    static func makeBuiltInPlugins() -> [any NotchPlugin] {
        [
            MusicPlugin(),
            BatteryPlugin(),
            CalendarPlugin(),
            WeatherPlugin(),
            ShelfPlugin(),
            WebcamPlugin(),
            NotificationsPlugin(),
            ClipboardPlugin(),
            HabitTrackerPlugin(),
            PomodoroPlugin(),
            TeleprompterPlugin(),
            DisplaySurfacePlugin()
        ]
    }
}
