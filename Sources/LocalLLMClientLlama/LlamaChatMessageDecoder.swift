import LocalLLMClientCore
import Foundation
import Jinja

public enum MessageChunk: Equatable, Hashable {
    case text(String)
    case image([LLMInputImage])
    case video([LLMInputImage]) // Placeholder for future video support
}

public protocol LlamaChatMessageDecoder: Sendable {
    func templateValue(from messages: [LLMInput.Message]) -> [LLMInput.ChatTemplateMessage]
    func applyTemplate(_ messages: [LLMInput.ChatTemplateMessage], chatTemplate: String, additionalContext: [String: Any]?, tools: [AnyLLMTool]) throws(LLMError) -> String
    func extractChunks(prompt: String, imageChunks: [[LLMInputImage]]) throws -> [MessageChunk]
    func decode(_ messages: [LLMInput.ChatTemplateMessage], context: Context, multimodal: MultimodalContext?, tools: [AnyLLMTool]) throws
}

public extension LlamaChatMessageDecoder {
    func templateValue(from messages: [LLMInput.Message]) -> [LLMInput.ChatTemplateMessage] {
        messages.map { message in
            var value: [String: any Sendable] = [
                "role": message.role.rawValue,
                "content": (0..<message.attachments.images().count).map { _ in
                    ["type": "image"] as [String: String]
                } + [["type": "text", "text": message.content] as [String: String]],
            ]
            
            // Add tool_call_id if present in metadata for tool messages
            if message.role == .tool, let toolCallID = message.metadata["tool_call_id"] {
                value["tool_call_id"] = toolCallID
            }
            
            return LLMInput.ChatTemplateMessage(
                value: value,
                attachments: message.attachments
            )
        }
    }

    func applyTemplate(
        _ messages: [LLMInput.ChatTemplateMessage],
        chatTemplate: String,
        additionalContext: [String: Any]? = nil,
        tools: [AnyLLMTool] = []
    ) throws(LLMError) -> String {
        do {
            let template = try Template(chatTemplate)

            var templateContext: [String: Any] = [
                "add_generation_prompt": true
            ]

            var messages = messages.map(\.value)

            // Convert tools to the format expected by the template
            if !tools.isEmpty {
                let toolsJSON = tools.compactMap { $0.toOAICompatJSON() }
                templateContext["tools"] = toolsJSON
                if let index = messages.firstIndex(where: { $0["role"] as? String == "system" }) {
                    messages[index]["tools"] = String(decoding: try JSONSerialization.data(withJSONObject: toolsJSON, options: []), as: UTF8.self)
                }
            }

            templateContext["messages"] = messages

            if let additionalContext {
                templateContext.merge(additionalContext) { _, new in new }
            }

            return try template.render(templateContext)
        } catch {
            throw .invalidParameter(reason: "Failed to apply template: \(error.localizedDescription)")
        }
    }
    
    func extractChunks(prompt: String, imageChunks: [[LLMInputImage]]) throws -> [MessageChunk] {
        [.text(prompt)]
    }

    func decode(_ messages: [LLMInput.ChatTemplateMessage], context: Context, multimodal: MultimodalContext?, tools: [AnyLLMTool]) throws {
        let specialTokens: [String: String] = [
            "bos_token": String(utf8String: llama_vocab_get_text(context.model.vocab, max(0, llama_vocab_bos(context.model.vocab)))) ?? "",
            "eos_token": String(utf8String: llama_vocab_get_text(context.model.vocab, max(0, llama_vocab_eos(context.model.vocab)))) ?? "",
            "unk_token": String(utf8String: llama_vocab_get_text(context.model.vocab, 0)) ?? "",
            "sep_token": String(utf8String: llama_vocab_get_text(context.model.vocab, max(0, llama_vocab_sep(context.model.vocab)))) ?? "",
            "pad_token": String(utf8String: llama_vocab_get_text(context.model.vocab, max(0, llama_vocab_pad(context.model.vocab)))) ?? "",
            "cls_token": String(utf8String: llama_vocab_get_text(context.model.vocab, max(0, llama_vocab_bos(context.model.vocab)))) ?? "",
            "mask_token": ""
        ]

        let prompt = try applyTemplate(messages, chatTemplate: context.model.chatTemplate, additionalContext: specialTokens, tools: tools)
        let imagesChunks = messages.imageChunks()
        var chunks = try extractChunks(prompt: prompt, imageChunks: imagesChunks)
        context.removeCachedChunks(&chunks)

        for chunk in chunks {
            switch chunk {
            case .text(let text):
                try context.decode(text: text)
            case .image(let images):
                guard let multimodal else { throw LLMError.failedToDecode(reason: "no mmproj file") }
                let bitmap = try multimodal.chunks(images: images)
                try context.decode(bitmap: bitmap, with: multimodal)
            case .video:
                // Video not supported in this decoder yet
                break
            }

            context.addCache(for: chunk, position: context.position)
        }
    }
}

public struct LlamaCustomMessageDecoder: LlamaChatMessageDecoder {
    public init(
        tokenImageRegex: String = "<start_of_image>"
    ) {
        self.tokenImageRegex = tokenImageRegex
    }

    public let tokenImageRegex: String
    
    public func extractChunks(prompt: String, imageChunks: [[LLMInputImage]]) throws -> [MessageChunk] {
        let pattern = try Regex<Substring>(tokenImageRegex)
        var chunks: [MessageChunk] = []
        var lastIndex = prompt.startIndex
        var imageIndex = 0
        
        for match in prompt.matches(of: pattern) {
            if lastIndex < match.range.lowerBound {
                let prefix = prompt[lastIndex..<match.range.lowerBound]
                chunks.append(.text(String(prefix)))
            }
            
            if imageIndex < imageChunks.count {
                chunks.append(.image(imageChunks[imageIndex]))
                imageIndex += 1
            }
            
            lastIndex = match.range.upperBound
        }
        
        if lastIndex < prompt.endIndex {
            let suffix = prompt[lastIndex..<prompt.endIndex]
            chunks.append(.text(String(suffix)))
        }
        
        return chunks
    }
}

public struct LlamaQwen2VLMessageDecoder: LlamaChatMessageDecoder {
    public func extractChunks(prompt: String, imageChunks: [[LLMInputImage]]) throws -> [MessageChunk] {
        let pattern = /(?<image><\|image_pad\|>)|(?<video><\|video_pad\|>)/
        var chunks = [MessageChunk]()
        var lastIndex = prompt.startIndex
        var imageIndex = 0
        
        for match in prompt.matches(of: pattern) {
            if lastIndex < match.range.lowerBound {
                let prefix = prompt[lastIndex..<match.range.lowerBound]
                chunks.append(.text(String(prefix)))
            }
            
            if let _ = match.output.image {
                guard imageIndex < imageChunks.count else { 
                    throw LLMError.failedToDecode(reason: "Not enough image chunks")
                }
                chunks.append(.image(imageChunks[imageIndex]))
                imageIndex += 1
            } else if let _ = match.output.video {
                // TODO: Handle video - add placeholder for now
                chunks.append(.video([]))
            }
            
            lastIndex = match.range.upperBound
        }
        
        if lastIndex < prompt.endIndex {
            let suffix = prompt[lastIndex..<prompt.endIndex]
            chunks.append(.text(String(suffix)))
        }
        
        return chunks
    }
}

public struct LlamaLlama3_2VMessageDecoder: LlamaChatMessageDecoder {
    public func templateValue(from messages: [LLMInput.Message]) -> [LLMInput.ChatTemplateMessage] {
        messages.map { message in
            switch message.role {
            case .system, .assistant, .custom, .tool:
                LLMInput.ChatTemplateMessage(
                    value: ["role": message.role.rawValue, "content": message.content],
                    attachments: message.attachments
                )
            case .user:
                LLMInput.ChatTemplateMessage(
                    value: [
                        "role": message.role.rawValue,
                        "content": [["type": "text", "text": message.content]] + (0..<message.attachments.images().count).map { _ in
                            ["type": "image"]
                        },
                    ],
                    attachments: message.attachments
                )
            }
        }
    }

    public func extractChunks(prompt: String, imageChunks: [[LLMInputImage]]) throws -> [MessageChunk] {
        let decoder = LlamaCustomMessageDecoder(tokenImageRegex: #"<\|image\|>"#)
        return try decoder.extractChunks(prompt: prompt, imageChunks: imageChunks)
    }
}

public struct LlamaChatMLMessageDecoder: LlamaChatMessageDecoder {
    public func templateValue(from messages: [LLMInput.Message]) -> [LLMInput.ChatTemplateMessage] {
        messages.map { message in
            LLMInput.ChatTemplateMessage(
                value: ["role": message.role.rawValue, "content": message.content],
                attachments: message.attachments
            )
        }
    }
}

// MARK: - Utilities

private extension [LLMInput.ChatTemplateMessage] {
    func imageChunks() -> [[LLMInputImage]] {
        compactMap { message in
            let images = message.attachments.images()
            return images.isEmpty ? nil : images
        }
    }
}

private extension [LLMAttachment] {
    func images() -> [LLMInputImage] {
        return compactMap { attachment -> LLMInputImage? in
            if case let .image(image) = attachment.content {
                return image
            }
            return nil
        }
    }
}
