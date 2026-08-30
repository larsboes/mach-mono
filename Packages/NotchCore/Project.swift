import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "NotchCore",
    targets: [
        Mach.framework(
            name: "NotchCore",
            dependencies: [
                .project(target: "NotchSettingsMacro", path: "../NotchSettingsMacro"),
                .external(name: "Defaults"),
            ]
        ),
        Mach.unitTests(for: "NotchCore"),
    ]
)
