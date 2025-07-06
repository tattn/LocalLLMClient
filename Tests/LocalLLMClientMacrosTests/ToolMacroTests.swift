import Testing
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import LocalLLMClientMacrosPlugin
import LocalLLMClientCore

@Suite
struct ToolMacroTests {
    let testMacros: [String: Macro.Type] = [
        "Tool": ToolMacro.self
    ]
    
    @Test
    func expandsWithExtension() {
        assertMacroExpansion(
            """
            @Tool("search")
            struct SearchTool {
                let description = "Search for information"
                
                struct Arguments: Decodable, ToolSchemaGeneratable {
                    let query: String
                    static var argumentsSchema: LLMToolArgumentsSchema {
                        ["query": .string(description: "Search query")]
                    }
                }
                
                func call(arguments: Arguments) async throws -> ToolOutput {
                    return ["result": "Found something"]
                }
            }
            """,
            expandedSource: """
            struct SearchTool {
                public let name = "search"
                let description = "Search for information"
                
                struct Arguments: Decodable, ToolSchemaGeneratable {
                    let query: String
                    static var argumentsSchema: LLMToolArgumentsSchema {
                        ["query": .string(description: "Search query")]
                    }
                }
                
                func call(arguments: Arguments) async throws -> ToolOutput {
                    return ["result": "Found something"]
                }
            }
            
            extension SearchTool: LLMTool {
            }
            """,
            macros: testMacros
        )
    }
    
    @Test
    func expandsWithMinimalStruct() {
        assertMacroExpansion(
            """
            @Tool("minimal")
            struct MinimalTool {
            }
            """,
            expandedSource: """
            struct MinimalTool {
                public let name = "minimal"
            }
            
            extension MinimalTool: LLMTool {
            }
            """,
            macros: testMacros
        )
    }
    
    @Test
    func failsOnNonStructTypes() {
        assertMacroExpansion(
            """
            @Tool("invalid")
            class InvalidTool {
            }
            """,
            expandedSource: """
            class InvalidTool {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Tool can only be applied to structs", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }
    
    @Test
    func failsWithoutNameArgument() {
        assertMacroExpansion(
            """
            @Tool
            struct NoNameTool {
            }
            """,
            expandedSource: """
            struct NoNameTool {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Tool requires a string literal argument for the name", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }
    
}
