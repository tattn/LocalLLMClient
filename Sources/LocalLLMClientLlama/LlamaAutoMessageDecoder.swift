import LocalLLMClient
import Jinja

enum ChatTemplate {
    case `default`
    case gemma3
    case qwen2_5_VL
    case llama3_2V // llama4
    case phi4

    var decoder: any LlamaChatMessageDecoder {
        switch self {
        case .default: LlamaChatMLMessageDecoder()
        case .gemma3: LlamaCustomMessageDecoder(tokenImageRegex: "<start_of_image>")
        case .qwen2_5_VL: LlamaQwen2VLMessageDecoder()
        case .llama3_2V: LlamaLlama3_2VMessageDecoder()
        case .phi4: LlamaChatMLMessageDecoder()
        }
    }
}

public struct LlamaAutoMessageDecoder: LlamaChatMessageDecoder {
    var chatTemplate: ChatTemplate = .default

    public init(chatTemplate: String) {
        guard let template = try? Template(chatTemplate) else {
            return
        }

        let textMarker = "$$TEXT$$"
        let image = LLMInputImage()
        let messages = [LLMInput.Message(role: .user, content: textMarker, attachments: [.image(image)])]
        let candidateTemplates: [ChatTemplate] = [.gemma3, .qwen2_5_VL, .llama3_2V, .phi4]
        var maxLength = 0

        for candidate in candidateTemplates {
            let value = candidate.decoder.templateValue(from: messages).map(\.value)
            do {
                // Pick the template that can render
                let rendered = try template.render(["messages": value])
                if maxLength < rendered.count {
                    maxLength = rendered.count
                    self.chatTemplate = candidate
                }

                // If possible, pick the template that can extract image chunks
                let chunks = try candidate.decoder.extractChunks(prompt: rendered, imageChunks: [[image]])
                if chunks.hasVisionItems() {
                    break
                }
            } catch {
            }
        }
    }

    public func templateValue(from messages: [LLMInput.Message]) -> [LLMInput.ChatTemplateMessage] {
        chatTemplate.decoder.templateValue(from: messages)
    }

    public func applyTemplate(_ messages: [LLMInput.ChatTemplateMessage], chatTemplate: String, additionalContext: [String: Any]?) throws(LLMError) -> String {
        try self.chatTemplate.decoder.applyTemplate(messages, chatTemplate: chatTemplate, additionalContext: additionalContext)
    }

    public func extractChunks(prompt: String, imageChunks: [[LLMInputImage]]) throws -> [MessageChunk] {
        try chatTemplate.decoder.extractChunks(prompt: prompt, imageChunks: imageChunks)
    }

    public func decode(_ messages: [LLMInput.ChatTemplateMessage], context: Context, clipModel: ClipModel?) throws -> DecodingContext {
        try chatTemplate.decoder.decode(messages, context: context, clipModel: clipModel)
    }
}

private extension [MessageChunk] {
    func hasVisionItems() -> Bool {
        contains { chunk in
            switch chunk {
            case .text: false
            case .image, .video: true
            }
        }
    }
}
