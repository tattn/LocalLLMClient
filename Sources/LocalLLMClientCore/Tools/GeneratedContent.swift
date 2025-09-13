import Foundation

/// Response containing generated text and any tool calls
public struct GeneratedContent: Sendable {
    /// The generated text response
    public let text: String

    /// Any tool calls made by the model
    public let toolCalls: [LLMToolCall]

    /// Creates a new generated content response
    /// - Parameters:
    ///   - text: The generated text
    ///   - toolCalls: Any tool calls made by the model
    public init(text: String, toolCalls: [LLMToolCall] = []) {
        self.text = text
        self.toolCalls = toolCalls
    }
}