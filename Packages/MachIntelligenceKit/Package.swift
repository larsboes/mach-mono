// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "MachIntelligenceKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v26)
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", exact: "0.16.0")
    ],
    products: [
        .library(
            name: "MachIntelligenceKit",
            targets: ["MachIntelligenceKit"]
        )
    ],
    targets: [
        .target(
            name: "MachIntelligenceKit",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ]
        ),
        .testTarget(
            name: "MachIntelligenceKitTests",
            dependencies: ["MachIntelligenceKit"]
        )
    ]
)
