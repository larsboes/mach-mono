// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "MachSoundKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v26)
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
            name: "MachSoundDSP",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "MachSoundKit",
            dependencies: [
                "MachSoundDSP"
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MachSoundKitTests",
            dependencies: ["MachSoundKit", "MachSoundDSP"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
