// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "MacroVisionKit",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "MacroVisionKit",
            targets: ["MacroVisionKit"]),
        .executable(
            name: "FullScreenMonitorExample",
            targets: ["FullScreenMonitorExample"]),
    ],
    targets: [
        .target(
            name: "MacroVisionKit"),
        .executableTarget(
            name: "FullScreenMonitorExample",
            dependencies: ["MacroVisionKit"],
            path: "Examples"),
    ]
) 