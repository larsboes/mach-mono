import ProjectDescription

/// Shared values and target factories for mach-mono.
///
/// Replaces `resources/tools/defs.bzl` and `Packages/NotchPlugins/notch_plugin_defs.bzl`.
/// Keep it small: it is imported by every `Project.swift`.
public enum Mach {

    // MARK: - Constants

    /// Minimum macOS deployment target for all first-party Apple targets.
    /// Bumping this is a one-line change here; never hardcode it in a manifest.
    public static let minimumMacOS = "26.0"

    public static let destinations: Destinations = [.mac]
    public static let deploymentTargets: DeploymentTargets = .macOS(minimumMacOS)

    public static let organization = "com.larsboes"

    /// Version is stamped by CI from the release tag; local builds get the fallback.
    /// `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` replace Bazel's
    /// `apple_bundle_version` + `--embed_label`.
    public static var marketingVersion: String {
        Environment.machVersion.getString(default: "0.0.0")
    }

    public static var buildNumber: String {
        Environment.machBuild.getString(default: "0")
    }

    public static var versionSettings: SettingsDictionary {
        [
            "MARKETING_VERSION": .string(marketingVersion),
            "CURRENT_PROJECT_VERSION": .string(buildNumber),
        ]
    }

    // MARK: - Base Settings

    public static func baseSettings(_ extra: SettingsDictionary = [:]) -> Settings {
        var base: SettingsDictionary = [
            // Language mode, not compiler version. rules_swift defaulted to 5,
            // so the code has never been compiled in Swift 6 mode. Moving to 6
            // is a real change with real errors to fix; it is not part of a
            // build-system migration.
            "SWIFT_VERSION": "5.0",
            "MACOSX_DEPLOYMENT_TARGET": .string(minimumMacOS),
            "DEAD_CODE_STRIPPING": "YES",

            // Build unsigned, then sign the finished bundle with `codesign`.
            // This is what the Bazel pipeline did, and it is deliberate: the
            // app-groups entitlement makes Xcode demand a provisioning profile
            // otherwise. The release job overrides these on the xcodebuild
            // command line to produce a Developer ID signed build.
            "CODE_SIGN_STYLE": "Manual",
            "CODE_SIGN_IDENTITY": "",
            "CODE_SIGNING_REQUIRED": "NO",
            "CODE_SIGNING_ALLOWED": "NO",
        ]
        base.merge(extra) { _, new in new }
        return .settings(base: base)
    }

    // MARK: - Frameworks

    /// A first-party library. Static by default, mirroring `swift_library` under
    /// Bazel: nothing here needs its own dylib, and static linking keeps the
    /// bundle small.
    ///
    /// Pass `product: .framework` when an app extension also links it. An
    /// extension cannot depend on a static framework — each bundle would carry
    /// its own copy of the code and its own copy of any global state.
    public static func framework(
        name: String,
        product: Product = .staticFramework,
        sources: SourceFilesList = ["Sources/**"],
        resources: ResourceFileElements? = nil,
        dependencies: [TargetDependency] = []
    ) -> Target {
        .target(
            name: name,
            destinations: destinations,
            product: product,
            bundleId: "\(organization).\(name)",
            deploymentTargets: deploymentTargets,
            sources: sources,
            resources: resources,
            dependencies: dependencies,
            settings: baseSettings()
        )
    }

    /// Unit tests for a first-party library.
    public static func unitTests(
        for name: String,
        sources: SourceFilesList = ["Tests/**"],
        dependencies: [TargetDependency] = []
    ) -> Target {
        .target(
            name: "\(name)Tests",
            destinations: destinations,
            product: .unitTests,
            bundleId: "\(organization).\(name)Tests",
            deploymentTargets: deploymentTargets,
            sources: sources,
            dependencies: [.target(name: name)] + dependencies,
            settings: baseSettings()
        )
    }

    // MARK: - Notch Plugins

    /// Dependencies every built-in notch plugin gets.
    /// Mirrors `_PLUGIN_SHARED_DEPS` in `notch_plugin_defs.bzl`.
    public static let pluginSharedDependencies: [TargetDependency] = [
        .target(name: "NotchPluginCore"),
        .project(target: "NotchCore", path: "../NotchCore"),
        .project(target: "NotchServices", path: "../NotchServices"),
        .project(target: "NotchUI", path: "../NotchUI"),
        .external(name: "Defaults"),
        .external(name: "KeyboardShortcuts"),
    ]

    /// One built-in plugin module.
    /// `path` is the directory under `Sources/NotchPlugins/BuiltIn/`.
    public static func notchPlugin(
        name: String,
        path: String,
        dependencies: [TargetDependency] = []
    ) -> Target {
        .target(
            name: name,
            destinations: destinations,
            product: .staticFramework,
            bundleId: "\(organization).\(name)",
            deploymentTargets: deploymentTargets,
            sources: [
                "Sources/NotchPlugins/BuiltIn/\(path)/**/*.swift",
                "Sources/NotchPlugins/BuiltIn/BuiltInPluginImports.swift",
            ],
            dependencies: pluginSharedDependencies + dependencies,
            settings: baseSettings()
        )
    }
}
