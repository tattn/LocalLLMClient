import Foundation
import LlamaSwift

public final class LlamaClient: Client {
    private let context: Context

    public init(url: URL, parameter: LLMParameter = .default) throws {
        context = try Context(url: url, parameter: parameter)
    }

    public func predict(_ input: String) async throws -> String {
        var finalResult = ""
        for try await token in predict(input) {
            finalResult += token
#if DEBUG
            print(token)
#endif
        }
        return finalResult
    }

    public func predict(_ input: String) -> Generator {
        Generator(text: input, context: context)
    }
}
