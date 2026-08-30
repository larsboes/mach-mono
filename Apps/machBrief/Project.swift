import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "machBrief",
    organizationName: Mach.organization,
    targets: [
        // Shared App Intents, used by both the app and its widget.
        Mach.framework(
            name: "machBriefIntents",
            product: .framework,
            sources: ["machBrief/AppIntents/**/*.swift"],
            dependencies: [.project(target: "MachBriefKit", path: "../../Packages/MachBriefKit")]
        ),
        .target(
            name: "machBriefWidget",
            destinations: Mach.destinations,
            product: .appExtension,
            bundleId: "mach.brief.widget",
            deploymentTargets: Mach.deploymentTargets,
            infoPlist: .file(path: "machBriefWidget/Info.plist"),
            sources: ["machBriefWidget/**/*.swift"],
            entitlements: "machBriefWidget/machBriefWidget.entitlements",
            dependencies: [
                .target(name: "machBriefIntents"),
                .project(target: "MachBriefKit", path: "../../Packages/MachBriefKit"),
            ],
            settings: Mach.baseSettings(Mach.versionSettings)
        ),
        .target(
            name: "machBrief",
            destinations: Mach.destinations,
            product: .app,
            bundleId: "mach.brief",
            deploymentTargets: Mach.deploymentTargets,
            infoPlist: .file(path: "machBrief/Info.plist"),
            sources: [
                .glob("machBrief/**/*.swift", excluding: ["machBrief/AppIntents/**"])
            ],
            entitlements: "machBrief/machBrief.entitlements",
            dependencies: [
                .target(name: "machBriefWidget"),
                .target(name: "machBriefIntents"),
                .project(target: "MachBriefKit", path: "../../Packages/MachBriefKit"),
            ],
            settings: Mach.baseSettings(Mach.versionSettings)
        ),
    ]
)
