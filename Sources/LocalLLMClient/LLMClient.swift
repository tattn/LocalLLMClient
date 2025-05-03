import Foundation

public protocol LLMClient: Sendable {
    associatedtype Generator: AsyncSequence where Generator.Element == String
    func generateText(from input: LLMInput) async throws -> String
    func textStream(from input: LLMInput) async throws -> Generator
}

public extension LLMClient {
    func generateText(from input: LLMInput) async throws -> String {
        var finalResult = ""
        for try await token in try await textStream(from: input) as Generator {
            finalResult += token
        }
        return finalResult
    }

    func generateText(from input: String) async throws -> String {
        try await generateText(from: .init(prompt: input))
    }

    func textStream(from input: String) async throws -> Generator {
        try await textStream(from: .init(prompt: input))
    }
}

public enum LocalLLMClient {}
