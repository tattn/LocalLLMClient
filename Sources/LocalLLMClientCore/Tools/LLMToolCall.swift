import Foundation

/// A representation of a tool call made by the model.
public struct LLMToolCall: Sendable, Hashable, Equatable, Identifiable {
    /// The unique identifier for the tool call.
    public let id: String

    /// The name of the tool that was called.
    public let name: String

    /// The arguments that were passed to the tool as a JSON string.
    public let arguments: String

    /// Creates a new tool call.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the tool call. Defaults to a new UUID.
    ///   - name: The name of the tool that was called.
    ///   - arguments: The arguments that were passed to the tool as a JSON string.
    public init(id: String = UUID().uuidString, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}