// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "MachBriefKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "MachBriefKit",
            targets: ["MachBriefKit"]
        )
    ],
    targets: [
        .target(
            name: "MachBriefKit",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MachBriefKitTests",
            dependencies: ["MachBriefKit"]
        )
    ]
)
