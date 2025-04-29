import Foundation
import LlamaSwift
import Synchronization

public final class LlamaClient: LLMClient {
    private let context: Mutex<Context>

    public init(url: URL, parameter: LLMParameter = .default) throws {
        context = try .init(Context(url: url, parameter: parameter))
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
        context.withLock {
            Generator(text: input, context: $0)
        }
    }
}
