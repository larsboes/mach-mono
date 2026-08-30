import ProjectDescription

/// Listed explicitly rather than globbed. `Apps/machHealth` is a three-file
/// stub with no Bazel target and no build here either; a glob would pick it up
/// because it carries a Package.swift.
let workspace = Workspace(
    name: "mach-mono",
    projects: [
        "Apps/machNotch",
        "Apps/machBrief",
        "Packages/NotchCore",
        "Packages/NotchUI",
        "Packages/NotchServices",
        "Packages/NotchPlugins",
        "Packages/NotchSettingsMacro",
        "Packages/MachBriefKit",
        "Packages/MachIntelligenceKit",
        "Packages/MachSoundKit",
        "Packages/MacroVisionKit",
        "Packages/HealthExportKit",
    ]
)
