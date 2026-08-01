// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchUI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "NotchUI",
            targets: ["NotchUI"]
        )
    ],
    dependencies: [
        .package(path: "../NotchCore"),
        .package(url: "https://github.com/airbnb/lottie-spm.git", exact: "4.6.1"),
        .package(url: "https://github.com/1998code/SwiftGlass.git", exact: "26.0.1")
    ],
    targets: [
        .target(
            name: "NotchUI",
            dependencies: [
                .product(name: "NotchCore", package: "NotchCore"),
                .product(name: "Lottie", package: "lottie-spm"),
                .product(name: "SwiftGlass", package: "SwiftGlass")
            ]
        ),
        .testTarget(
            name: "NotchUITests",
            dependencies: ["NotchUI"]
        )
    ]
)
