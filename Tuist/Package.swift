// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import struct ProjectDescription.PackageSettings

let packageSettings = PackageSettings(
    // Third-party packages link statically, matching what rules_swift did.
    // Only MediaRemoteAdapter ships as a dynamic framework in the bundle.
    productTypes: [:],
    baseSettings: .settings(
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release"),
        ]
    )
)
#endif

let package = Package(
    name: "mach-mono",
    dependencies: [
        .package(url: "https://github.com/ChimeHQ/AsyncXPCConnection", exact: "1.3.0"),
        .package(url: "https://github.com/sindresorhus/Defaults", exact: "9.0.9"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "3.0.1"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", exact: "1.1.0"),
        .package(url: "https://github.com/airbnb/lottie-spm.git", exact: "4.6.1"),
        .package(url: "https://github.com/EmergeTools/Pow", exact: "1.0.6"),
        .package(url: "https://github.com/Lakr233/SkyLightWindow", exact: "1.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.3"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", exact: "0.16.0"),
        .package(url: "https://github.com/apple/swift-collections.git", exact: "1.6.0"),
        .package(url: "https://github.com/apple/swift-syntax.git", exact: "602.0.0"),
        .package(url: "https://github.com/1998code/SwiftGlass.git", exact: "26.0.1"),
        // AudioKit and SoundpipeAudioKit were declared under Bazel but never
        // imported by first-party code — MachSoundKit and MachSoundDSP are
        // already AudioKit-free. Dropped rather than carried.
    ]
)
