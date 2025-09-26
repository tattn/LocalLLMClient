import Foundation

/// A protocol representing a client for LLM
public protocol LLMClient: Sendable {
    associatedtype TextGenerator: AsyncSequence & Sendable where Self.TextGenerator.Element == String
    associatedtype ResponseGenerator: AsyncSequence & Sendable where Self.ResponseGenerator.Element == StreamingChunk
    associatedtype ResumeGenerator: AsyncSequence & Sendable where Self.ResumeGenerator.Element == StreamingChunk

    /// Processes the provided input and returns the complete generated text
    /// - Parameter input: The input to process
    /// - Returns: The complete generated text
    /// - Throws: An error if text generation fails
    func generateText(from input: LLMInput) async throws -> String

    /// Processes the provided input and returns a stream of text tokens asynchronously
    /// - Parameter input: The input to process
    /// - Returns: An asynchronous sequence that emits text tokens
    /// - Throws: An error if text generation fails
    func textStream(from input: LLMInput) async throws -> TextGenerator

    /// Generates text with tool calls from the given input.
    /// - Parameter input: The input to generate from
    /// - Returns: Generated content containing text and optional tool calls
    /// - Throws: An error if generation fails or tools are not supported
    func generateToolCalls(from input: LLMInput) async throws -> GeneratedContent

    /// Resumes generation after tool calls have been executed and returns the complete generated text.
    /// - Parameters:
    ///   - toolCalls: The tool calls that were made
    ///   - toolOutputs: The outputs from executing the tools (id, output) pairs
    ///   - originalInput: The original input that triggered the tool calls
    /// - Returns: The complete generated text after resumption
    /// - Throws: An error if resumption fails or tools are not supported
    func resume(
        withToolCalls toolCalls: [LLMToolCall],
        toolOutputs: [(String, String)],
        originalInput: LLMInput
    ) async throws -> String

    /// Resumes generation after tool calls have been executed and returns a stream.
    /// - Parameters:
    ///   - toolCalls: The tool calls that were made
    ///   - toolOutputs: The outputs from executing the tools (id, output) pairs
    ///   - originalInput: The original input that triggered the tool calls
    /// - Returns: An asynchronous sequence that emits response content (text chunks, tool calls, etc.)
    /// - Throws: An error if resumption fails or tools are not supported
    func resumeStream(
        withToolCalls toolCalls: [LLMToolCall],
        toolOutputs: [(String, String)],
        originalInput: LLMInput
    ) async throws -> ResumeGenerator

    /// Generates a stream of responses from the given input.
    /// - Parameter input: The input to generate from
    /// - Returns: An asynchronous sequence that emits response content (text chunks, tool calls, etc.)
    /// - Throws: An error if generation fails or requested features are not supported
    func responseStream(from input: LLMInput) async throws -> ResponseGenerator

    /// Pauses any ongoing text generation
    func pauseGeneration() async

    /// Resumes previously paused text generation
    func resumeGeneration() async

    /// Whether the generation is currently paused
    var isGenerationPaused: Bool { get async }
}

public extension LLMClient {
    /// Processes the provided input and returns the complete generated text
    /// - Parameter input: The input to process
    /// - Returns: The complete generated text
    /// - Throws: An error if text generation fails
    func generateText(from input: LLMInput) async throws -> String {
        var finalResult = ""
        for try await token in try await textStream(from: input) as TextGenerator {
            finalResult += token
        }
        return finalResult
    }

    /// Resumes generation after tool calls have been executed and returns the complete generated text.
    /// - Parameters:
    ///   - toolCalls: The tool calls that were made
    ///   - toolOutputs: The outputs from executing the tools (id, output) pairs
    ///   - originalInput: The original input that triggered the tool calls
    /// - Returns: The complete generated text after resumption
    /// - Throws: An error if resumption fails or tools are not supported
    func resume(
        withToolCalls toolCalls: [LLMToolCall],
        toolOutputs: [(String, String)],
        originalInput: LLMInput
    ) async throws -> String {
        var result = ""
        for try await chunk in try await resumeStream(withToolCalls: toolCalls, toolOutputs: toolOutputs, originalInput: originalInput) {
            switch chunk {
            case .text(let text):
                result += text
            case .toolCall:
                // Tool calls in resume are not expected but handled for completeness
                break
            }
        }
        return result
    }

    /// Convenience method to generate text from a plain string input
    /// - Parameter input: The plain text input string
    /// - Returns: The complete generated text as a String
    /// - Throws: An error if text generation fails
    func generateText(from input: String) async throws -> String {
        try await generateText(from: .init(.plain(input)))
    }

    /// Convenience method to stream text from a plain string input
    /// - Parameter input: The plain text input string
    /// - Returns: An asynchronous sequence that emits text tokens
    /// - Throws: An error if text generation fails
    func textStream(from input: String) async throws -> TextGenerator {
        try await textStream(from: .init(.plain(input)))
    }
}

// Extension for default tool calling behavior
public extension LLMClient where ResponseGenerator == AsyncThrowingStream<StreamingChunk, any Error>, ResumeGenerator == AsyncThrowingStream<StreamingChunk, any Error> {
    func generateToolCalls(from input: LLMInput) async throws -> GeneratedContent {
        throw LLMError.invalidParameter(reason: "Tool calls are not supported by this LLM client")
    }

    func resumeStream(
        withToolCalls toolCalls: [LLMToolCall],
        toolOutputs: [(String, String)],
        originalInput: LLMInput
    ) async throws -> AsyncThrowingStream<StreamingChunk, any Error> {
        throw LLMError.invalidParameter(reason: "Tool calls are not supported by this LLM client")
    }

    func responseStream(from input: LLMInput) async throws -> AsyncThrowingStream<StreamingChunk, any Error> {
        throw LLMError.invalidParameter(reason: "Tool calls are not supported by this LLM client")
    }
}

/// Namespace for local LLM client implementations
public enum LocalLLMClient {}
