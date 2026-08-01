// swift-tools-version: 6.0
// This Package.swift exists solely so rules_swift_package_manager can generate
// Bazel targets from the resolved dependencies. It is NOT the build source of
// truth — actual builds go through MODULE.bazel + Apps/*/BUILD.bazel.
// Kept at tools-version 6.0 so CI runners (Swift 6.2.x) can parse this shim
// without requiring a Swift 6.3 toolchain.
import PackageDescription

let package = Package(
    name: "mach-mono",
    products: [],
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
        .package(url: "https://github.com/AudioKit/AudioKit", exact: "5.7.2"),
        .package(url: "https://github.com/AudioKit/SoundpipeAudioKit", exact: "5.7.4"),
    ],
    targets: []
)
