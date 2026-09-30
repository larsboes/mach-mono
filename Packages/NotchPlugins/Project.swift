import ProjectDescription
import ProjectDescriptionHelpers

/// Every built-in plugin is its own module, so the plugin boundary is a build
/// boundary. Mirrors the target shape `notch_plugin_defs.bzl` produced.
let builtInPlugins: [Target] = [
    Mach.notchPlugin(name: "NotchBatteryPlugin", path: "BatteryPlugin"),
    Mach.notchPlugin(
        name: "NotchBriefPlugin",
        path: "BriefPlugin",
        dependencies: [.project(target: "MachBriefKit", path: "../MachBriefKit")]
    ),
    Mach.notchPlugin(name: "NotchCalendarPlugin", path: "CalendarPlugin"),
    Mach.notchPlugin(name: "NotchClipboardPlugin", path: "ClipboardPlugin"),
    Mach.notchPlugin(name: "NotchDisplaySurfacePlugin", path: "DisplaySurfacePlugin"),
    Mach.notchPlugin(name: "NotchHabitTrackerPlugin", path: "HabitTrackerPlugin"),
    Mach.notchPlugin(name: "NotchMusicPlugin", path: "MusicPlugin"),
    Mach.notchPlugin(name: "NotchNotificationsPlugin", path: "NotificationsPlugin"),
    Mach.notchPlugin(name: "NotchPomodoroPlugin", path: "PomodoroPlugin"),
    Mach.notchPlugin(name: "NotchShelfPlugin", path: "ShelfPlugin"),
    Mach.notchPlugin(name: "NotchSystemStatsPlugin", path: "SystemStatsPlugin"),
    Mach.notchPlugin(name: "NotchTeleprompterPlugin", path: "TeleprompterPlugin"),
    Mach.notchPlugin(name: "NotchWeatherPlugin", path: "WeatherPlugin"),
    Mach.notchPlugin(name: "NotchWebcamPlugin", path: "WebcamPlugin"),
    Mach.notchPlugin(name: "NotchAxonPlugin", path: "AxonPlugin"),
    // Opt-in only: pulls in MachSoundKit, which the default app never links.
    Mach.notchPlugin(
        name: "NotchSoundscapePlugin",
        path: "SoundscapePlugin",
        dependencies: [.project(target: "MachSoundKit", path: "../MachSoundKit")]
    ),
]

/// Every plugin module depends on this one, so it must not depend on them.
let pluginCore = Mach.framework(
    name: "NotchPluginCore",
    sources: .init(
        globs: [
            .glob(
                "Sources/NotchPlugins/Core/**/*.swift",
                excluding: ["Sources/NotchPlugins/Core/PluginRegistry.swift"]
            ),
            .glob("Sources/NotchPlugins/UI/**/*.swift"),
        ]
    ),
    dependencies: [
        .project(target: "NotchCore", path: "../NotchCore"),
        .project(target: "NotchServices", path: "../NotchServices"),
        .project(target: "NotchUI", path: "../NotchUI"),
        .external(name: "Defaults"),
    ]
)

/// Default facade: re-exports the built-ins and owns the registry.
/// Excludes Soundscape, and therefore MachSoundKit.
let pluginsFacade = Mach.framework(
    name: "NotchPlugins",
    sources: [
        "Sources/NotchPlugins/BuiltInPluginViewBridge.swift",
        "Sources/NotchPlugins/Core/PluginRegistry.swift",
        "Sources/NotchPlugins/Imports.swift",
        "Sources/NotchPlugins/NotchPlugins.swift",
    ],
    dependencies: [.target(name: "NotchPluginCore")]
        + builtInPlugins
            .filter { $0.name != "NotchSoundscapePlugin" }
            .map { .target(name: $0.name) }
        + [
            .project(target: "NotchCore", path: "../NotchCore"),
            .project(target: "NotchServices", path: "../NotchServices"),
            .project(target: "NotchUI", path: "../NotchUI"),
        ]
)

/// Explicit opt-in facade for builds that include Soundscape.
let soundscapeFacade = Mach.framework(
    name: "NotchPluginsWithSoundscape",
    sources: ["Sources/NotchPlugins/SoundscapePluginRegistry.swift"],
    dependencies: [
        .target(name: "NotchPlugins"),
        .target(name: "NotchSoundscapePlugin"),
    ]
)

let project = Project(
    name: "NotchPlugins",
    targets: [pluginCore] + builtInPlugins + [
        pluginsFacade,
        soundscapeFacade,
        Mach.unitTests(
            for: "NotchPlugins",
            dependencies: [.target(name: "NotchSoundscapePlugin")]
        ),
    ]
)
