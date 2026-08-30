import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "HealthExportKit",
    targets: [
        Mach.framework(name: "HealthExportKit", sources: ["Sources/HealthExportKit/**"]),
        Mach.unitTests(for: "HealthExportKit"),
    ]
)
