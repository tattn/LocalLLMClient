import Foundation
import LlamaSwift
@_exported import LLMCommon

public protocol LLMClient: Sendable {
    func predict(_ input: LLMInput) async throws -> String
    func predict(_ input: LLMInput) -> Generator
}

public extension LLMClient {
    func predict(_ input: LLMInput) async throws -> String {
        try await predict(input)
    }

    func predict(_ input: LLMInput) -> Generator {
        predict(input)
    }

    func predict(_ input: String) async throws -> String {
        try await predict(.init(prompt: input))
    }

    func predict(_ input: String) -> Generator {
        predict(.init(prompt: input))
    }
}

public enum LocalLLMClient {
    public static func makeClient(url: URL, parameter: LLMParameter = .default) throws -> LLMClient {
        try LlamaClient(url: url, parameter: parameter)
    }

    public static func setVerbose(_ verbose: Bool) {
        setLlamaVerbose(verbose)
    }
}
