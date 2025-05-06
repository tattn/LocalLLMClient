import Foundation

public protocol LLMClient: Sendable {
    associatedtype Error: Swift.Error
    associatedtype TextGenerator: AsyncSequence<String, Error> & Sendable
    func generateText(from input: LLMInput) async throws -> String
    func textStream(from input: LLMInput) async throws -> TextGenerator
}

public extension LLMClient {
    func generateText(from input: LLMInput) async throws -> String {
        var finalResult = ""
        for try await token in try await textStream(from: input) as TextGenerator {
            finalResult += token
        }
        return finalResult
    }

    func generateText(from input: String) async throws -> String {
        try await generateText(from: .init(prompt: input))
    }

    func textStream(from input: String) async throws -> TextGenerator {
        try await textStream(from: .init(prompt: input))
    }
}

public enum LocalLLMClient {}

public struct AnyLLMClient: LLMClient {
    public let client: any LLMClient

    public init(_ client: any LLMClient) {
        self.client = client
    }

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
