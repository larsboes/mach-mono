load("@rules_swift//swift:swift.bzl", "swift_library")

_PLUGIN_SHARED_DEPS = [
    ":NotchPluginCore",
    "//Packages/NotchCore:NotchCore",
    "//Packages/NotchServices:NotchServices",
    "//Packages/NotchUI:NotchUI",
    "@swiftpkg_defaults//:Defaults",
    "@swiftpkg_keyboardshortcuts//:KeyboardShortcuts",
]

def notch_plugin_library(name, module_name, path, deps = []):
    swift_library(
        name = name,
        srcs = native.glob(["Sources/NotchPlugins/BuiltIn/%s/**/*.swift" % path]) + [
            "Sources/NotchPlugins/BuiltIn/BuiltInPluginImports.swift",
        ],
        module_name = module_name,
        visibility = ["//visibility:private"],
        deps = _PLUGIN_SHARED_DEPS + deps,
        defines = ["SWIFT_PACKAGE"],
    )
