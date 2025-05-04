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
        let images = try input.attachments.compactMap {
            switch $0 {
            case let .image(image):
                return try UserInput.Image.ciImage(llmInputImageToCIImage(image))
            }
        }

        let chat: [Chat.Message] = [
//            .system("You are a helpful assistant"),
            .user(input.prompt, images: images),
        ]

        var userInput = UserInput(
            chat: chat, additionalContext: ["enable_thinking": false])
        userInput.processing.resize = .init(width: 448, height: 448)

        let modelContainer = try context.withLock { context in
            if !images.isEmpty, !context.supportsVision {
                throw LLMError.visionUnsupported
            }
            return context.modelContainer
        }

        return try await modelContainer.perform { [userInput] context in
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
}

public extension LocalLLMClient {
    static func mlx(url: URL, parameter: MLXClient.Parameter = .default) async throws -> MLXClient {
        try await MLXClient(url: url, parameter: parameter)
    }
}
