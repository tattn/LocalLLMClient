import Foundation

/// Protocol for LLM clients that support tool calling
public protocol LLMToolCallable: LLMClient {

    /// Generates text and potentially tool calls from the input
    /// - Parameter input: The input to process
    /// - Returns: Generated content including text and any tool calls
    /// - Throws: An error if generation fails
    func generateToolCalls(from input: LLMInput) async throws -> GeneratedContent

    /// Resumes generation after tool calls have been executed
    /// - Parameters:
    ///   - toolCalls: The tool calls that were made
    ///   - toolOutputs: The outputs from executing the tools (toolCallID, output)
    ///   - originalInput: The original input that led to the tool calls
    /// - Returns: The final generated text after incorporating tool results
    /// - Throws: An error if generation fails
    func resume(
        withToolCalls toolCalls: [LLMToolCall],
        toolOutputs: [(String, String)],
        originalInput: LLMInput
    ) async throws -> String
}