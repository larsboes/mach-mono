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
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", exact: "0.16.0")
    ],
    targets: [
        .target(
            name: "MachIntelligenceKit",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MachIntelligenceKitTests",
            dependencies: ["MachIntelligenceKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
