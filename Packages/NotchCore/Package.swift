// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "NotchCore",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "NotchCore",
            targets: ["NotchCore"]
        )
    ],
    dependencies: [
        .package(path: "../NotchSettingsMacro"),
        .package(url: "https://github.com/sindresorhus/Defaults", exact: "9.0.9")
    ],
    targets: [
        .target(
            name: "NotchCore",
            dependencies: [
                .product(name: "NotchSettingsMacro", package: "NotchSettingsMacro"),
                .product(name: "Defaults", package: "Defaults")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "NotchCoreTests",
            dependencies: ["NotchCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
