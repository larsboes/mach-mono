import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "NotchUI",
    targets: [
        Mach.framework(
            name: "NotchUI",
            dependencies: [
                .project(target: "NotchCore", path: "../NotchCore"),
                .project(target: "MacroVisionKit", path: "../MacroVisionKit"),
                .external(name: "Lottie"),
                .external(name: "SwiftGlass"),
            ]
        ),
        Mach.unitTests(for: "NotchUI"),
    ]
)
