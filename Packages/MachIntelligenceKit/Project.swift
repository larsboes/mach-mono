import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "MachIntelligenceKit",
    targets: [
        Mach.framework(
            name: "MachIntelligenceKit",
            dependencies: [.external(name: "SQLite")]
        ),
        Mach.unitTests(for: "MachIntelligenceKit"),
    ]
)
