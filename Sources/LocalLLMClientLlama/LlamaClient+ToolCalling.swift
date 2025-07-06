import Foundation
import LocalLLMClientCore

/// Extension to LlamaClient to add tool calling capabilities
extension LlamaClient: LLMToolCallable {

    /// Generates text from the input and parses it for tool calls
    ///
    /// - Parameter input: The input to process
    /// - Returns: Generated content including text and any tool calls
    /// - Throws: An error if text generation fails
    public func generateToolCalls(from input: LLMInput) async throws -> GeneratedContent {
        let text = try await generateText(from: input)
        let toolCalls = LlamaToolCallParser.parseToolCalls(from: text, format: chatFormat)
        return GeneratedContent(text: text, toolCalls: toolCalls ?? [])
    }


    /// Resumes a conversation with tool outputs
    ///
    /// - Parameters:
    ///   - toolCalls: The tool calls that were made
    ///   - toolOutputs: The outputs from executing the tools (toolCallID, output)
    ///   - originalInput: The original input that generated the tool call
    /// - Returns: The model's response to the tool outputs
    /// - Throws: An error if text generation fails
    public func resume(
        withToolCalls toolCalls: [LLMToolCall],
        toolOutputs: [(String, String)],
        originalInput: LLMInput
    ) async throws -> String {
        guard case let .chat(messages) = originalInput.value else {
            throw LLMError.invalidParameter(reason: "Original input must be a chat")
        }
        
        var updatedMessages = messages

        // Add tool messages for each tool output
        for (toolCallID, output) in toolOutputs {
            updatedMessages.append(.tool(output, toolCallID: toolCallID))
        }
        
        // Create a new input with the updated messages
        let updatedInput = LLMInput.chat(updatedMessages)
        
        // Generate a response to the tool outputs
        return try await generateText(from: updatedInput)
    }
}
