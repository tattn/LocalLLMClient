import Foundation
import LocalLLMClient

public final class LlamaClient: LLMClient {
    private let context: Context
    private let clipModel: ClipModel?
    private let messageDecoder: any LlamaChatMessageDecoder

    public init(
        url: URL,
        clip: sending ClipModel?,
        parameter: Parameter,
        messageDecoder: (any LlamaChatMessageDecoder)?
    ) throws {
        context = try Context(url: url, parameter: parameter)
        if let clip {
            clipModel = .init(clip)
        } else {
            clipModel = nil
        }
        self.messageDecoder = messageDecoder ?? LlamaAutoMessageDecoder(chatTemplate: context.model.chatTemplate)
    }

    public func textStream(from input: LLMInput) throws -> Generator {
        context.clear()
        do {
            switch input.value {
            case .plain(let text):
                try context.decode(text: text)
            case .chatTemplate(let messages):
                try messageDecoder.decode(messages, context: context, clipModel: clipModel)
            case .chat(let messages):
                let value = messageDecoder.templateValue(from: messages)
                try messageDecoder.decode(value, context: context, clipModel: clipModel)
            }
        } catch {
            throw LLMError.decodingFailed
        }

        return Generator(context: context)
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
        context
    }
}
#endif
