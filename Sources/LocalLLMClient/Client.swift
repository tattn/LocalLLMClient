import Foundation
import LlamaSwift
@_exported import LLMCommon

public protocol Client {
    func predict(_ input: String) async throws -> String
    func predict(_ input: String) -> Generator
}

public enum LocalLLMClient {
    public static func makeClient(url: URL, parameter: LLMParameter = .default) throws -> Client {
        try LlamaClient(url: url, parameter: parameter)
    }
}
