import LocalLLMClient
import MLX
import MLXLMCommon
import Foundation
import Synchronization

public final actor MLXClient: LLMClient {
    private let context: Mutex<Context>
    private let parameter: MLXClient.Parameter

    nonisolated public init(url: URL, parameter: Parameter = .default) async throws {
        context = try await .init(Context(url: url, parameter: parameter))
        self.parameter = parameter
    }

    public func textStream(from input: LLMInput) async throws -> AsyncStream<String> {
        let images = try input.attachments.compactMap {
            switch $0 {
            case let .image(image):
                return try UserInput.Image.ciImage(llmInputImageToCIImage(image))
            }
        }

        let chat: [Chat.Message] = switch input.value {
        case .plain(let text):
            [.user(text, images: images)]
        case .chatTemplate(let messages):
            messages.map {
                Chat.Message(
                    role: .init(rawValue: $0["role"] as? String ?? "") ?? .user,
                    content: $0["content"] as? String ?? "",
                    images: images
                )
            }
        case .chat(let messages):
            messages.map {
                Chat.Message(
                    role: .init(rawValue: $0.role.rawValue) ?? .user,
                    content: $0.content,
                    images: images
                )
            }
        }

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

            return .init { continuation in
                let task = Task {
                    for await generated in stream {
                        continuation.yield(generated.chunk ?? "")
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in
                    task.cancel()
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
