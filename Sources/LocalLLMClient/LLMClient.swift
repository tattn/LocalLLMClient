import Foundation
import LlamaSwift
@_exported import LLMCommon

public protocol LLMClient: Sendable {
    func predict(_ input: String) async throws -> String
    func predict(_ input: String) -> Generator
}

public enum LocalLLMClient {
    public static func makeClient(url: URL, parameter: LLMParameter = .default) throws -> LLMClient {
        try LlamaClient(url: url, parameter: parameter)
    }

    public static func setVerbose(_ verbose: Bool) {
        setLlamaVerbose(verbose)
    }
}
