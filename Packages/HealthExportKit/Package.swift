// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "HealthExportKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v26),
    ],
    products: [
        .library(name: "HealthExportKit", targets: ["HealthExportKit"]),
    ],
    targets: [
        .target(name: "HealthExportKit"),
        .testTarget(
            name: "HealthExportKitTests",
            dependencies: ["HealthExportKit"]
        ),
    ]
)
