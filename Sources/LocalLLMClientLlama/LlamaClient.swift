import Foundation
import LocalLLMClient

public final class LlamaClient: LLMClient {
    private let context: Context
    private let multimodal: MultimodalContext?
    private let messageDecoder: any LlamaChatMessageDecoder

    public init(
        url: URL,
        mmprojURL: URL?,
        parameter: Parameter,
        messageDecoder: (any LlamaChatMessageDecoder)?,
        verbose: Bool
    ) throws {
        context = try Context(url: url, parameter: parameter)
        if let mmprojURL {
            multimodal = try MultimodalContext(url: mmprojURL, context: context, parameter: parameter, verbose: verbose)
        } else {
            multimodal = nil
        }
        self.messageDecoder = messageDecoder ?? LlamaAutoMessageDecoder(chatTemplate: context.model.chatTemplate)
    }

    public func textStream(from input: LLMInput) throws -> Generator {
        do {
            switch input.value {
            case .plain(let text):
                context.clear()
                try context.decode(text: text)
            case .chatTemplate(let messages):
                try messageDecoder.decode(messages, context: context, multimodal: multimodal)
            case .chat(let messages):
                let value = messageDecoder.templateValue(from: messages)
                try messageDecoder.decode(value, context: context, multimodal: multimodal)
            }
        } catch {
            throw LLMError.failedToDecode(reason: error.localizedDescription)
        }

        return Generator(context: context)
    }
}

public extension LocalLLMClient {
    static func llama(
        url: URL,
        mmprojURL: URL? = nil,
        parameter: LlamaClient.Parameter = .default,
        messageDecoder: (any LlamaChatMessageDecoder)? = nil,
        verbose: Bool = false
    ) async throws -> LlamaClient {
        setLlamaVerbose(verbose)
        return try LlamaClient(
            url: url,
            mmprojURL: mmprojURL,
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

    var _multimodal: MultimodalContext? {
        multimodal
    }
}
#endif
