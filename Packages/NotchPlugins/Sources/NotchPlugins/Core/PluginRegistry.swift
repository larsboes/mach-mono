//
//  PluginRegistry.swift
//  machNotch
//
//  Single place to declare built-in plugins.
//  AppObjectGraph reads this list — add new plugins here without touching AppObjectGraph.
//

import Foundation
import NotchBatteryPlugin
import NotchBriefPlugin
import NotchCalendarPlugin
import NotchClipboardPlugin
import NotchDisplaySurfacePlugin
import NotchHabitTrackerPlugin
import NotchMusicPlugin
import NotchNotificationsPlugin
import NotchPomodoroPlugin
import NotchShelfPlugin
import NotchSystemStatsPlugin
import NotchTeleprompterPlugin
import NotchWeatherPlugin
import NotchWebcamPlugin

@MainActor
public enum PluginRegistry {
    public static func makeBuiltInDescriptors() -> [PluginDescriptor] {
        [
            musicDescriptor,
            batteryDescriptor,
            calendarDescriptor,
            weatherDescriptor,
            shelfDescriptor,
            webcamDescriptor,
            notificationsDescriptor,
            clipboardDescriptor,
            habitTrackerDescriptor,
            pomodoroDescriptor,
            teleprompterDescriptor,
            displaySurfaceDescriptor,
            systemStatsDescriptor,
            briefDescriptor,
        ]
    }

    private static var musicDescriptor: PluginDescriptor {
        PluginDescriptor(
            id: PluginID.music,
            metadata: PluginMetadata(
                name: "Music",
                description: "Control music playback from the notch",
                icon: "music.note",
                category: .media
            ),
            capabilities: [.closedNotchContent, .expandedPanelContent, .settingsContent, .menuBarContent, .exportable, .positioned],
            closedNotchPosition: .center,
            supportedExportFormats: [.json],
            factory: { MusicPlugin() }
        )
    }

    private static var batteryDescriptor: PluginDescriptor {
        PluginDescriptor(
            id: PluginID.battery,
            metadata: PluginMetadata(
                name: "Battery",
                description: "Monitor battery status and get notifications",
                icon: "battery.100",
                category: .system
            ),
            capabilities: [.closedNotchContent, .expandedPanelContent, .settingsContent, .menuBarContent, .positioned],
            closedNotchPosition: .farRight,
            factory: { BatteryPlugin() }
        )
    }

    private static var calendarDescriptor: PluginDescriptor {
        PluginDescriptor(
            id: PluginID.calendar,
            metadata: PluginMetadata(
                name: "Calendar",
                description: "View upcoming events and reminders",
                icon: "calendar",
                category: .productivity
            ),
            capabilities: [.expandedPanelContent, .settingsContent, .exportable],
            supportedExportFormats: [.json, .csv, .ical],
            factory: { CalendarPlugin() }
        )
    }

    private static var weatherDescriptor: PluginDescriptor {
        PluginDescriptor(
            id: PluginID.weather,
            metadata: PluginMetadata(
                name: "Weather",
                description: "View current weather conditions",
                icon: "cloud.sun.fill",
                category: .utilities
            ),
            capabilities: [.closedNotchContent, .expandedPanelContent, .settingsContent, .menuBarContent, .positioned],
            closedNotchPosition: .right,
            factory: { WeatherPlugin() }
        )
    }

    private static var shelfDescriptor: PluginDescriptor {
        PluginDescriptor(
            id: PluginID.shelf,
            metadata: PluginMetadata(
                name: "Shelf",
                description: "Temporary storage for files and links",
                icon: "tray.full.fill",
                category: .productivity
            ),
            capabilities: [.expandedPanelContent, .settingsContent, .exportable],
            supportedExportFormats: [.json, .csv],
            factory: { ShelfPlugin() }
        )
    }

    private static var webcamDescriptor: PluginDescriptor {
        PluginDescriptor(
            id: PluginID.webcam,
            metadata: PluginMetadata(
                name: "Webcam Mirror",
                description: "Mirror your camera in the notch",
                icon: "camera.fill",
                category: .utilities
            ),
            capabilities: [.expandedPanelContent],
            factory: { WebcamPlugin() }
        )
    }

    private static var notificationsDescriptor: PluginDescriptor {
        PluginDescriptor(
            id: PluginID.notifications,
            metadata: PluginMetadata(
                name: "Notifications",
                description: "View and manage notifications",
                icon: "bell.badge.fill",
                category: .system
            ),
            capabilities: [.expandedPanelContent, .settingsContent],
            factory: { NotificationsPlugin() }
        )
    }

    private static var clipboardDescriptor: PluginDescriptor {
        PluginDescriptor(
            id: PluginID.clipboard,
            metadata: PluginMetadata(
                name: "Clipboard",
                description: "View and manage clipboard history",
                icon: "doc.on.clipboard",
                category: .utilities
            ),
            capabilities: [.expandedPanelContent],
            factory: { ClipboardPlugin() }
        )
    }

    private static var habitTrackerDescriptor: PluginDescriptor {
        PluginDescriptor(
            id: PluginID.habitTracker,
            metadata: PluginMetadata(
                name: "Habit Tracker",
                description: "Track your daily habits directly from the notch",
                icon: "checkmark.circle.fill",
                category: .productivity
            ),
            capabilities: [.closedNotchContent, .expandedPanelContent, .settingsContent, .exportable],
            supportedExportFormats: [.json, .csv],
            factory: { HabitTrackerPlugin() }
        )
    }

    private static var pomodoroDescriptor: PluginDescriptor {
        PluginDescriptor(
            id: PluginID.pomodoro,
            metadata: PluginMetadata(
                name: "Pomodoro Timer",
                description: "Focus sessions right from the notch",
                icon: "timer",
                category: .productivity
            ),
            capabilities: [.closedNotchContent, .expandedPanelContent, .settingsContent, .menuBarContent, .exportable],
            supportedExportFormats: [.json, .csv],
            factory: { PomodoroPlugin() }
        )
    }

    private static var teleprompterDescriptor: PluginDescriptor {
        PluginDescriptor(
            id: PluginID.teleprompter,
            metadata: PluginMetadata(
                name: "Teleprompter",
                description: "Eye-contact friendly teleprompter",
                icon: "text.justify.left",
                category: .productivity
            ),
            capabilities: [.closedNotchContent, .expandedPanelContent, .settingsContent],
            factory: { TeleprompterPlugin() }
        )
    }

    private static var displaySurfaceDescriptor: PluginDescriptor {
        PluginDescriptor(
            id: PluginID.displaySurface,
            metadata: PluginMetadata(
                name: "Display Surface",
                description: "Generic ambient display for remote triggers",
                icon: "rectangle.inset.filled",
                category: .utilities
            ),
            capabilities: [.closedNotchContent, .expandedPanelContent],
            factory: { DisplaySurfacePlugin() }
        )
    }

    private static var systemStatsDescriptor: PluginDescriptor {
        PluginDescriptor(
            id: PluginID.systemStats,
            metadata: PluginMetadata(
                name: "System Stats",
                description: "Monitor CPU, memory, disk, and network activity",
                icon: "gauge.with.dots.needle.50percent",
                category: .system
            ),
            capabilities: [.closedNotchContent, .expandedPanelContent, .settingsContent, .positioned],
            closedNotchPosition: .farRight,
            factory: { SystemStatsPlugin() }
        )
    }

    private static var briefDescriptor: PluginDescriptor {
        PluginDescriptor(
            id: PluginID.brief,
            metadata: PluginMetadata(
                name: "Brief",
                description: "Word, quote, fact, and mantra — all in one hover panel.",
                icon: "text.book.closed",
                category: .productivity
            ),
            capabilities: [.closedNotchContent, .expandedPanelContent, .settingsContent, .positioned],
            closedNotchPosition: .right,
            factory: { BriefPlugin() }
        )
    }
}
