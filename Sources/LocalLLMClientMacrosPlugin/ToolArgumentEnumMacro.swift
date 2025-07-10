import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct ToolArgumentEnumMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // Ensure the macro is applied to an enum
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: ToolArgumentEnumDiagnostic.notAnEnum
                )
            )
            return []
        }
        
        // Create extension with the required conformances
        let extensionDecl = try ExtensionDeclSyntax(
            """
            extension \(enumDecl.name): Decodable, ToolArgumentType, CaseIterable {}
            """
        )
        
        return [extensionDecl]
    }
}

// Diagnostic messages for the macro
enum ToolArgumentEnumDiagnostic: String, DiagnosticMessage {
    case notAnEnum = "@ToolArgumentEnum can only be applied to enums"
    
    var severity: DiagnosticSeverity { .error }
    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "LocalLLMClientMacros", id: rawValue)
    }
}