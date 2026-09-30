import ProjectDescription
import ProjectDescriptionHelpers

/// Sources shared by both app variants.
let appSources: SourceFilesList = .init(
    globs: [
        .glob(
            "machNotch/**/*.swift",
            excluding: [
                // Work in progress.
                "machNotch/menu/StatusBarMenu.swift"
            ]
        )
    ]
)

let appResources: ResourceFileElements = [
    // Reference the catalog itself. Globbing inside it makes Xcode register the
    // catalog twice, which duplicates every generated asset symbol.
    "machNotch/Assets.xcassets",
    "machNotch/Localizable.xcstrings",
    "machNotch/welcome.m4a",
    "machNotch/animations/**",
    "mediaremote-adapter/mediaremote-adapter.pl",
]

/// Privileged helper.
///
/// The bundle id must equal `XPCHelperClient.serviceName`
/// ("com.larsboes.machnotch.xpc-helper"), because that is what
/// `NSXPCConnection(serviceName:)` resolves against. The Bazel targets used
/// "com.larsboes.machNotch.MachNotchXPCHelper", which never matched, so the
/// helper could not connect in a Bazel build. The committed Xcode project had
/// the correct value; this restores it.
///
/// Both variants keep that id — an embedded XPC service resolves inside its own
/// app bundle, so the two apps do not compete. Only the product name differs,
/// because Xcode writes both into one build directory.
func xpcHelper(soundscape: Bool) -> Target {
    .target(
        name: soundscape ? "MachNotchXPCHelperWithSoundscape" : "MachNotchXPCHelper",
        destinations: Mach.destinations,
        product: .xpc,
        productName: soundscape ? "MachNotchXPCHelperSoundscape" : "MachNotchXPCHelper",
        bundleId: "com.larsboes.machnotch.xpc-helper",
        deploymentTargets: Mach.deploymentTargets,
        infoPlist: .file(path: "MachNotchXPCHelper/Info.plist"),
        sources: ["MachNotchXPCHelper/**/*.swift"],
        entitlements: "MachNotchXPCHelper/MachNotchXPCHelper.entitlements",
        settings: Mach.baseSettings(Mach.versionSettings)
    )
}

func app(soundscape: Bool) -> Target {
    let name = soundscape ? "machNotchWithSoundscape" : "machNotch"
    var settings = Mach.versionSettings
    if soundscape {
        settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "$(inherited) MACH_NOTCH_SOUNDSCAPE"
    }

    return .target(
        name: name,
        destinations: Mach.destinations,
        product: .app,
        productName: name,
        bundleId: soundscape ? "com.larsboes.machNotch.soundscape" : "com.larsboes.machNotch",
        deploymentTargets: Mach.deploymentTargets,
        infoPlist: .file(path: "machNotch/Info.plist"),
        sources: appSources,
        resources: appResources,
        entitlements: "machNotch/machNotch.entitlements",
        dependencies: [
            .target(name: soundscape ? "MachNotchXPCHelperWithSoundscape" : "MachNotchXPCHelper"),
            // Private NowPlaying API. Ships as a dynamic framework, so it is
            // embedded in the app bundle rather than linked statically.
            .framework(path: "mediaremote-adapter/MediaRemoteAdapter.framework"),
            .project(target: "NotchCore", path: "../../Packages/NotchCore"),
            .project(target: "NotchUI", path: "../../Packages/NotchUI"),
            .project(target: "NotchServices", path: "../../Packages/NotchServices"),
            .project(target: "NotchSettingsMacro", path: "../../Packages/NotchSettingsMacro"),
            .project(target: "MacroVisionKit", path: "../../Packages/MacroVisionKit"),
            .project(target: "MachBriefKit", path: "../../Packages/MachBriefKit"),
            .project(
                target: soundscape ? "NotchPluginsWithSoundscape" : "NotchPlugins",
                path: "../../Packages/NotchPlugins"
            ),
            .external(name: "AsyncXPCConnection"),
            .external(name: "Defaults"),
            .external(name: "KeyboardShortcuts"),
            .external(name: "LaunchAtLogin"),
            .external(name: "Lottie"),
            .external(name: "SkyLightWindow"),
            .external(name: "Sparkle"),
            .external(name: "SQLite"),
            .external(name: "Collections"),
            .external(name: "SwiftGlass"),
        ],
        settings: Mach.baseSettings(settings)
    )
}

let project = Project(
    name: "machNotch",
    organizationName: Mach.organization,
    targets: [
        xpcHelper(soundscape: false),
        xpcHelper(soundscape: true),
        app(soundscape: false),
        app(soundscape: true),
        .target(
            name: "machNotchTests",
            destinations: Mach.destinations,
            product: .unitTests,
            bundleId: "com.larsboes.machNotchTests",
            deploymentTargets: Mach.deploymentTargets,
            sources: ["machNotchTests/**"],
            dependencies: [.target(name: "machNotch")],
            settings: Mach.baseSettings()
        ),
    ]
)
