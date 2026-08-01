// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "machHealth",
    platforms: [.iOS(.v17)],
    products: [
        .executable(name: "machHealth", targets: ["machHealth"]),
    ],
    dependencies: [
        .package(path: "../../Packages/HealthExportKit"),
    ],
    targets: [
        .executableTarget(
            name: "machHealth",
            dependencies: ["HealthExportKit"],
            path: "machHealth"
        ),
    ]
)
