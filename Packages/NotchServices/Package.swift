// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchServices",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "NotchServices",
            targets: ["NotchServices"]
        )
    ],
    dependencies: [
        .package(path: "../NotchCore"),
        .package(path: "../MachIntelligenceKit"),
        .package(path: "../MacroVisionKit"),
        .package(url: "https://github.com/ChimeHQ/AsyncXPCConnection", exact: "1.3.0"),
        .package(url: "https://github.com/sindresorhus/Defaults", exact: "9.0.9"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "3.0.1"),
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.3"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", exact: "0.16.0")
    ],
    targets: [
        .target(
            name: "NotchServices",
            dependencies: [
                .product(name: "NotchCore", package: "NotchCore"),
                .product(name: "MachIntelligenceKit", package: "MachIntelligenceKit"),
                .product(name: "MacroVisionKit", package: "MacroVisionKit"),
                .product(name: "AsyncXPCConnection", package: "AsyncXPCConnection"),
                .product(name: "Defaults", package: "Defaults"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "SQLite", package: "SQLite.swift")
            ]
        ),
        .testTarget(
            name: "NotchServicesTests",
            dependencies: ["NotchServices"]
        )
    ]
)
