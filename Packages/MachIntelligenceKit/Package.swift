// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "MachIntelligenceKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "MachIntelligenceKit",
            targets: ["MachIntelligenceKit"]
        )
    ],
    targets: [
        .target(name: "MachIntelligenceKit"),
        .testTarget(
            name: "MachIntelligenceKitTests",
            dependencies: ["MachIntelligenceKit"]
        )
    ]
)
