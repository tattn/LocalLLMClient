import Foundation

public protocol LLMClient: Sendable {
    associatedtype Generator
    func predict(_ input: LLMInput) async throws -> String
    func predict(_ input: LLMInput) throws -> Generator
    static func setVerbose(_ verbose: Bool)
}

public extension LLMClient {
    func predict(_ input: String) async throws -> String {
        try await predict(.init(prompt: input))
    }

    func predict(_ input: String) throws -> Generator {
        try predict(.init(prompt: input))
    }
}

public enum LocalLLMClient {}
