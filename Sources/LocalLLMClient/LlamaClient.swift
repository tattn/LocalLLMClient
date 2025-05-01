import Foundation
import LlamaSwift
import Synchronization

public final class LlamaClient: LLMClient {
    private let context: Mutex<Context>

    public init(url: URL, parameter: LLMParameter = .default) throws {
        context = try .init(Context(url: url, parameter: parameter))
    }

    public func predict(_ input: LLMInput, options: PredictOptions) async throws -> String {
        var finalResult = ""
        for try await token in predict(input, options: options) {
            finalResult += token
#if DEBUG
            print(token)
#endif
        }
        return finalResult
    }

    public func predict(_ input: LLMInput, options: PredictOptions) -> Generator {
        context.withLock {
            Generator(text: input.prompt, context: $0, special: options.parsesSpecial ?? false)
        }
    }
}
