// swift-tools-version: 6.3
import PackageDescription

// Project.swift drives the app build and splits this package into
// NotchPluginCore, one target per built-in plugin, and a facade that owns the
// registry. This manifest publishes only NotchPluginCore: that is the Plugin
// SDK surface, and by design it does not depend on any plugin. The built-ins
// and the registry are host implementation, so a third-party plugin must not
// need them to compile.
let package = Package(
    name: "NotchPlugins",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "NotchPluginCore",
            targets: ["NotchPluginCore"]
        )
    ],
    dependencies: [
        .package(path: "../NotchCore"),
        .package(path: "../NotchServices"),
        .package(path: "../NotchUI"),
        .package(url: "https://github.com/sindresorhus/Defaults", exact: "9.0.9")
    ],
    targets: [
        .target(
            name: "NotchPluginCore",
            dependencies: [
                .product(name: "NotchCore", package: "NotchCore"),
                .product(name: "NotchServices", package: "NotchServices"),
                .product(name: "NotchUI", package: "NotchUI"),
                .product(name: "Defaults", package: "Defaults")
            ],
            path: "Sources/NotchPlugins",
            // Owned by the facade target in Project.swift, and it pulls in every
            // built-in plugin.
            exclude: ["Core/PluginRegistry.swift"],
            sources: ["Core", "UI"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
