import Foundation
import Synchronization
import LocalLLMClient

public final class LlamaClient: LLMClient {
    private let context: Mutex<Context>
    private let clipModel: Mutex<ClipModel>?
    private let messageDecoder: any LlamaChatMessageDecoder

    public init(
        url: URL,
        clip: sending ClipModel?,
        parameter: Parameter,
        messageDecoder: (any LlamaChatMessageDecoder)?
    ) throws {
        context = try .init(Context(url: url, parameter: parameter))
        if let clip {
            clipModel = .init(clip)
        } else {
            clipModel = nil
        }
        let context = context.withLock { $0 }
        self.messageDecoder = messageDecoder ?? LlamaAutoMessageDecoder(context: context)
    }

    public func textStream(from input: LLMInput) throws -> Generator {
        try context.withLock { context in
            var decodeContext = DecodingContext(cursor: 0, special: true)
            let clipModel = clipModel?.withLock { $0 }

            do {
                switch input.value {
                case .plain(let text):
                    decodeContext = try context.decode(text: text, context: decodeContext)
                case .chatTemplate(let messages):
                    decodeContext = try messageDecoder.decode(messages, context: context, clipModel: clipModel)
                case .chat(let messages):
                    let value = messageDecoder.templateValue(from: messages)
                    decodeContext = try messageDecoder.decode(value, context: context, clipModel: clipModel)
                }
            } catch {
                throw LLMError.decodingFailed
            }

            return Generator(context: context, decodeContext: decodeContext)
        }
    }
}

public extension LocalLLMClient {
    static func llama(
        url: URL,
        clipURL: URL? = nil,
        parameter: LlamaClient.Parameter = .default,
        messageDecoder: (any LlamaChatMessageDecoder)? = nil,
        verbose: Bool = false
    ) async throws -> LlamaClient {
        setLlamaVerbose(verbose)
        let clipModel = try clipURL.map { try ClipModel(url: $0, verbose: verbose) }
        return try LlamaClient(url: url, clip: clipModel, parameter: parameter, messageDecoder: messageDecoder)
    }
}

#if DEBUG
extension LlamaClient {
    var _context: Context {
        context.withLock { $0 }
    }
}
#endif
