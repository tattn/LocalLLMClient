import Foundation
import LlamaSwift

public final class LlamaClient: Client {
    private let context: Context

    public init(url: URL) throws {
        context = try Context(url: url)
    }

    public func predict(_ input: String) async throws -> String {
        var finalResult = ""
        let generator = Generator(text: input, context: context)
        for try await token in generator {
            finalResult += token
#if DEBUG
            print(token)
#endif
        }
        return finalResult
    }
}
