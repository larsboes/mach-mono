import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "NotchServices",
    targets: [
        Mach.framework(
            name: "NotchServices",
            dependencies: [
                .project(target: "NotchCore", path: "../NotchCore"),
                .project(target: "MacroVisionKit", path: "../MacroVisionKit"),
                .project(target: "MachIntelligenceKit", path: "../MachIntelligenceKit"),
                .external(name: "AsyncXPCConnection"),
                .external(name: "Defaults"),
                .external(name: "KeyboardShortcuts"),
                .external(name: "Sparkle"),
                .external(name: "SQLite"),
            ]
        ),
        Mach.unitTests(for: "NotchServices"),
    ]
)
