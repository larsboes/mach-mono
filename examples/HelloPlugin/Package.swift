// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "HelloPlugin",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "HelloPlugin",
            targets: ["HelloPlugin"]
        )
    ],
    dependencies: [
        // Inside this repo the SDK is a path dependency. Outside it, replace this
        // with the released NotchPlugins package.
        .package(path: "../../Packages/NotchPlugins")
    ],
    targets: [
        .target(
            name: "HelloPlugin",
            dependencies: [
                .product(name: "NotchPluginCore", package: "NotchPlugins")
            ]
        ),
        .testTarget(
            name: "HelloPluginTests",
            dependencies: ["HelloPlugin"]
        )
    ]
)
