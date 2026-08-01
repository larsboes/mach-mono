// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchPlugins",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "NotchPlugins",
            targets: ["NotchPlugins"]
        )
    ],
    dependencies: [
        .package(path: "../NotchCore"),
        .package(path: "../NotchServices"),
        .package(path: "../MachIntelligenceKit"),
        .package(path: "../NotchUI"),
        .package(path: "../MachBriefKit"),
        .package(path: "../MachSoundKit"),
        .package(url: "https://github.com/sindresorhus/Defaults", exact: "9.0.9"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "3.0.1")
    ],
    targets: [
        .target(
            name: "NotchPlugins",
            dependencies: [
                .product(name: "NotchCore", package: "NotchCore"),
                .product(name: "NotchServices", package: "NotchServices"),
                .product(name: "MachIntelligenceKit", package: "MachIntelligenceKit"),
                .product(name: "NotchUI", package: "NotchUI"),
                .product(name: "MachBriefKit", package: "MachBriefKit"),
                .product(name: "MachSoundKit", package: "MachSoundKit"),
                .product(name: "Defaults", package: "Defaults"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ]
        ),
        .testTarget(
            name: "NotchPluginsTests",
            dependencies: ["NotchPlugins"]
        )
    ]
)
