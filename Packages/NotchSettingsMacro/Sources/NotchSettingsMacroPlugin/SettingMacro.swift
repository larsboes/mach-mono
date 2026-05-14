import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

public struct SettingMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              let type = binding.typeAnnotation?.type.description.filter({ !$0.isWhitespace }) else {
            return []
        }

        let arguments = node.arguments?.as(LabeledExprListSyntax.self)
        let keyArg = arguments?.first(where: { $0.label?.text == "key" })?.expression.description
        let defaultArg = arguments?.first(where: { $0.label?.text == "default" })?.expression.description ?? "nil"

        let defaultKeyName = keyArg ?? "\"\(identifier)\""

        let keyDecl: DeclSyntax = "static let \(raw: identifier)Key = Defaults.Key<\(raw: type)>(\(raw: defaultKeyName), default: \(raw: defaultArg))"
        return [keyDecl]
    }
}
