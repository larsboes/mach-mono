import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "NotchSettingsMacro",
    targets: [
        // The compiler plugin runs on the build machine, so it is macOS-only and
        // is a `.macro` product. Tuist generates the plugin tool and the
        // -load-plugin-executable flags; under Bazel this was
        // `swift_compiler_plugin`.
        .target(
            name: "NotchSettingsMacroPlugin",
            destinations: [.mac],
            product: .macro,
            bundleId: "\(Mach.organization).NotchSettingsMacroPlugin",
            deploymentTargets: Mach.deploymentTargets,
            sources: ["Sources/NotchSettingsMacroPlugin/**"],
            dependencies: [
                .external(name: "SwiftCompilerPlugin"),
                .external(name: "SwiftSyntax"),
                .external(name: "SwiftSyntaxBuilder"),
                .external(name: "SwiftSyntaxMacros"),
            ],
            settings: Mach.baseSettings()
        ),
        Mach.framework(
            name: "NotchSettingsMacro",
            sources: ["Sources/NotchSettingsMacro/**"],
            dependencies: [.macro(name: "NotchSettingsMacroPlugin")]
        ),
    ]
)
