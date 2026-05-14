import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct NotchSettingsMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SettingMacro.self,
    ]
}
