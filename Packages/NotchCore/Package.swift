// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "NotchCore",
            targets: ["NotchCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/Defaults", exact: "9.0.9")
    ],
    targets: [
        .target(
            name: "NotchCore",
            dependencies: [
                .product(name: "Defaults", package: "Defaults")
            ]
        ),
        .testTarget(
            name: "NotchCoreTests",
            dependencies: ["NotchCore"]
        )
    ]
)
