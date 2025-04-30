import Foundation
import LlamaSwift
@_exported import LLMCommon

public protocol LLMClient: Sendable {
    func predict(_ input: String, options: PredictOptions) async throws -> String
    func predict(_ input: String, options: PredictOptions) -> Generator
}

public extension LLMClient {
    func predict(_ input: String) async throws -> String {
        try await predict(input, options: .default)
    }

    func predict(_ input: String) -> Generator {
        predict(input, options: .default)
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
