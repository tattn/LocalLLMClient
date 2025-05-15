import Foundation

/// A protocol representing a client for LLM
public protocol LLMClient: Sendable {
    associatedtype TextGenerator: AsyncSequence & Sendable where Self.TextGenerator.Element == String

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

/// Namespace for local LLM client implementations
public enum LocalLLMClient {}

/// A type-erased wrapper around any LLMClient implementation
public struct AnyLLMClient: LLMClient {
    /// The underlying LLM client
    public let client: any LLMClient

    /// Creates a new type-erased wrapper around an LLMClient
    /// - Parameter client: The LLM client to wrap
    public init(_ client: any LLMClient) {
        self.client = client
    }

    /// Processes the provided input and returns a stream of text tokens asynchronously
    /// - Parameter input: The input to process
    /// - Returns: An AsyncThrowingStream that emits text tokens
    /// - Throws: An error if text generation fails
    public func textStream(from input: LLMInput) async throws -> AsyncThrowingStream<String, Swift.Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await text in try await client.textStream(from: input) {
                        continuation.yield(text as! String)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
