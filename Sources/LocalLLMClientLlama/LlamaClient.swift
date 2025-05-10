import Foundation
import Synchronization
import LocalLLMClient

public final class LlamaClient: LLMClient {
    private let context: Mutex<Context>
    private let clipModel: Mutex<ClipModel>?

    public init(url: URL, clip: sending ClipModel?, parameter: Parameter = .default) throws {
        context = try .init(Context(url: url, parameter: parameter))
        if let clip {
            clipModel = .init(clip)
        } else {
            clipModel = nil
        }
    }

    public func textStream(from input: LLMInput) throws -> Generator {
        try context.withLock { context in
            var decodeContext = DecodingContext(cursor: 0, special: input.parsesSpecial ?? true)
            let clipModel = clipModel?.withLock { $0 }

            do {
                for attachment in input.attachments {
                    switch attachment {
                    case let .image(image):
                        guard let clipModel else { throw LLMError.clipModelNotFound }
                        let embed = try clipModel.embedded(image: image)
                        decodeContext = try context.decode(
                            text: context.parameter.specialTokenImageStart,
                            context: decodeContext
                        )
                        decodeContext = try context.decode(imageEmbed: embed, context: decodeContext)
                        decodeContext = try context.decode(
                            text: context.parameter.specialTokenImageEnd,
                            context: decodeContext
                        )
                    }
                }

                switch input.value {
                case .plain(let text):
                    decodeContext = try context.decode(text: text, context: decodeContext)
                case .chatTemplate(let messages):
                    let prompt = try context.model.applyTemplate(messages)
                    decodeContext = try context.decode(text: prompt, context: decodeContext)
                case .chat(let messages):
                    let prompt = try context.model.applyTemplate(messages.makeTemplate())
                    decodeContext = try context.decode(text: prompt, context: decodeContext)
                }
            } catch {
                throw LLMError.decodingFailed
            }

            return Generator(context: context, decodeContext: decodeContext)
        }
    }
}

public extension LocalLLMClient {
    static func llama(url: URL, clipURL: URL? = nil, parameter: LlamaClient.Parameter = .default, verbose: Bool = false) async throws -> LlamaClient {
        setLlamaVerbose(verbose)
        let clipModel = try clipURL.map { try ClipModel(url: $0, verbose: verbose) }
        return try LlamaClient(url: url, clip: clipModel, parameter: parameter)
    }
}
