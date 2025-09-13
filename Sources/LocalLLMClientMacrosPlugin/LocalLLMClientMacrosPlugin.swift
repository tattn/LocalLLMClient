import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct LocalLLMClientMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ToolArgumentMacro.self,
        ToolArgumentsMacro.self,
        ToolArgumentEnumMacro.self,
        ToolMacro.self,
    ]
}