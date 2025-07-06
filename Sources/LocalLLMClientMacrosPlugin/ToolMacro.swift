import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

struct ToolDiagnostic: DiagnosticMessage {
    static let notAStruct = ToolDiagnostic(message: "@Tool can only be applied to structs", severity: .error)
    
    let message: String
    let severity: DiagnosticSeverity
    let diagnosticID: MessageID
    
    init(message: String, severity: DiagnosticSeverity) {
        self.message = message
        self.severity = severity
        self.diagnosticID = MessageID(domain: "LocalLLMClientMacros", id: "Tool")
    }
}

public struct ToolMacro: ExtensionMacro, MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.as(StructDeclSyntax.self) != nil else {
            let error = Diagnostic(
                node: declaration,
                message: ToolDiagnostic.notAStruct
            )
            context.diagnose(error)
            return []
        }
        
        let extensionDecl: DeclSyntax = """
            extension \(type.trimmed): LLMTool {}
            """
        
        guard let extensionSyntax = extensionDecl.as(ExtensionDeclSyntax.self) else {
            return []
        }
        
        return [extensionSyntax]
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.as(StructDeclSyntax.self) != nil else {
            let error = Diagnostic(
                node: declaration,
                message: ToolDiagnostic.notAStruct
            )
            context.diagnose(error)
            return []
        }
        
        guard case .argumentList(let argumentList) = node.arguments,
              let firstArgument = argumentList.first,
              let stringLiteral = firstArgument.expression.as(StringLiteralExprSyntax.self),
              let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) else {
            let error = Diagnostic(
                node: node,
                message: ToolDiagnostic(message: "@Tool requires a string literal argument for the name", severity: .error)
            )
            context.diagnose(error)
            return []
        }
        
        let toolName = segment.content.text
        
        let nameDecl: DeclSyntax = """
            public let name = "\(raw: toolName)"
            """
        
        return [nameDecl]
    }
}
