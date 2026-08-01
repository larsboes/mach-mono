// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MachSoundKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MachSoundKit",
            targets: ["MachSoundKit"]
        ),
        .library(
            name: "MachSoundDSP",
            targets: ["MachSoundDSP"]
        )
    ],
    dependencies: [],
    targets: [
        // Pure DSP, no AudioKit — isolated to avoid type-name collisions.
        .target(
            name: "MachSoundDSP"
        ),
        .target(
            name: "MachSoundKit",
            dependencies: [
                "MachSoundDSP"
            ]
        ),
        .testTarget(
            name: "MachSoundKitTests",
            dependencies: ["MachSoundKit", "MachSoundDSP"]
        )
    ]
)
