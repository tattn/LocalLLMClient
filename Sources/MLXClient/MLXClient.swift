import LocalLLMClient
import MLX
import MLXLMCommon
import Foundation
import Synchronization

public final class MLXClient: LLMClient {
    private let context: Mutex<Context>
    private let parameter: MLXClient.Parameter

    public init(url: URL, parameter: Parameter = .default) async throws {
        context = try await .init(Context(url: url))
        self.parameter = parameter
    }

    public func textStream(from input: LLMInput) async throws -> AsyncStream<String> {
        let chat: [Chat.Message] = [
//            .system("You are a helpful assistant"),
            .user(input.prompt),
        ]
        let userInput = UserInput(
            chat: chat, additionalContext: ["enable_thinking": false])

        let modelContainer = context.withLock { context in
            context.modelContainer
        }

        return try await modelContainer.perform { context in
            let lmInput = try await context.processor.prepare(input: userInput)
            let stream = try MLXLMCommon.generate(
                input: lmInput,
                parameters: parameter.parameters,
                context: context
            )

            return AsyncStream<String> { continuation in
                Task {
                    for await generated in stream {
                        continuation.yield(generated.chunk ?? "")
                    }
                    continuation.finish()
                }
            }
        }
    }

    public static func setVerbose(_ verbose: Bool) {
    }
}

public extension LocalLLMClient {
    static func mlx(url: URL, parameter: MLXClient.Parameter = .default) async throws -> MLXClient {
        try await MLXClient(url: url, parameter: parameter)
    }
}
