import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "MachBriefKit",
    targets: [
        // Resources are read through `Bundle.module` in Support/BundleJSON.swift,
        // which Tuist generates for a target that declares resources.
        // Dynamic: the machBrief widget extension links it too, and an
        // extension cannot depend on a static framework.
        Mach.framework(
            name: "MachBriefKit",
            product: .framework,
            // Support/Bundle+Module.swift is a hand-written `Bundle.module`
            // shim that existed because Bazel does not generate one. Tuist does,
            // so including both is a redeclaration.
            sources: .init(
                globs: [
                    .glob(
                        "Sources/**/*.swift",
                        excluding: ["Sources/MachBriefKit/Support/Bundle+Module.swift"]
                    )
                ]
            ),
            resources: ["Sources/MachBriefKit/Resources/**"]
        ),
        Mach.unitTests(for: "MachBriefKit"),
    ]
)
