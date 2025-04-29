import Foundation
@_exported import LLMCommon

public protocol Client {
    func predict(_ input: String) async throws -> String
}

public enum LocalLLMClient {
    public static func makeClient(url: URL) throws -> Client {
        try LlamaClient(url: url)
    }
}
