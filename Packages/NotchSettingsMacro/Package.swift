// swift-tools-version: 6.3
import CompilerPluginSupport
import PackageDescription

// Dual-declared like every other package here: Project.swift drives the Tuist
// build, this manifest lets the module resolve under plain `swift build`, which
// is how a third-party plugin consumes the SDK.
let package = Package(
    name: "NotchSettingsMacro",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "NotchSettingsMacro",
            targets: ["NotchSettingsMacro"]
        )
    ],
    dependencies: [
        // Pinned to match Tuist/Package.swift.
        .package(url: "https://github.com/apple/swift-syntax.git", exact: "602.0.0")
    ],
    targets: [
        .macro(
            name: "NotchSettingsMacroPlugin",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "NotchSettingsMacro",
            dependencies: ["NotchSettingsMacroPlugin"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
