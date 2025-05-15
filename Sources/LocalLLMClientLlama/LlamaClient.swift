import Foundation
import LocalLLMClient

public final class LlamaClient: LLMClient {
    private let context: Context
    private let clipModel: ClipModel?
    private let messageDecoder: any LlamaChatMessageDecoder

    public init(
        url: URL,
        clipURL: URL?,
        parameter: Parameter,
        messageDecoder: (any LlamaChatMessageDecoder)?,
        verbose: Bool
    ) throws {
        context = try Context(url: url, parameter: parameter)
        if let clipURL {
            clipModel = try ClipModel(url: clipURL, context: context, parameter: parameter, verbose: verbose)
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
        return try LlamaClient(
            url: url,
            clipURL: clipURL,
            parameter: parameter,
            messageDecoder: messageDecoder,
            verbose: verbose
        )
    }
}

#if DEBUG
extension LlamaClient {
    var _context: Context {
        context
    }

    var _clipModel: ClipModel? {
        clipModel
    }
}
#endif
