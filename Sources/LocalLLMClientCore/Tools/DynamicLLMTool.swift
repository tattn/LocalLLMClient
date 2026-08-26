import Foundation

/// The `LLMTool` standing behind a tool built from runtime data.
///
/// `AnyLLMTool` keeps a concrete tool around for `underlyingTool`, but a tool
/// declared at runtime has no Swift type of its own: its schema is data, not a
/// `ToolSchemaGeneratable` conformance. This carries the name and description so
/// that accessor still answers, and never runs — the dynamic initializer stores
/// the caller's closure directly.
public struct DynamicLLMTool: LLMTool {
    public struct Arguments: Decodable, ToolSchemaGeneratable {
        public static var argumentsSchema: LLMToolArgumentsSchema { [:] }
    }

    public let name: String
    public let description: String

    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        throw ToolError.executionFailed(
            toolName: name,
            underlyingError: CocoaError(.featureUnsupported))
    }
}
