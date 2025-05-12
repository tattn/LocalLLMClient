import LocalLLMClient
import Jinja

public protocol LlamaChatMessageDecoder: Sendable {
    func templateValue(from messages: [LLMInput.Message]) -> [LLMInput.ChatTemplateMessage]
    func applyTemplate(_ messages: [LLMInput.ChatTemplateMessage], context: Context, additionalContext: [String: Any]?) throws(LLMError) -> String
    func decode(_ messages: [LLMInput.ChatTemplateMessage], context: Context, clipModel: ClipModel?) throws -> DecodingContext
}

public extension LlamaChatMessageDecoder {
    func templateValue(from messages: [LLMInput.Message]) -> [LLMInput.ChatTemplateMessage] {
        messages.map { message in
            LLMInput.ChatTemplateMessage(
                value: [
                    "role": message.role.rawValue,
                    "content": message.content,
                    "type": "text",
                ],
                attachments: message.attachments
            )
        }
    }

    func applyTemplate(
        _ messages: [LLMInput.ChatTemplateMessage],
        context: Context,
        additionalContext: [String: Any]? = nil
    ) throws(LLMError) -> String {
        guard let chatTemplate = context.model.chatTemplate else {
            throw .failedToLoad(reason: "Failed to load template")
        }
        do {
            let template = try Template(chatTemplate)

            var templateContext: [String: Any] = [
                "messages": messages.map(\.value),
                "add_generation_prompt": true,
            ]
            //    if let tools {
            //        context["tools"] = tools
            //    }
            if let additionalContext {
                templateContext.merge(additionalContext) { _, new in new }
            }

            let specialTokenAttributes: [String] = [
                "bos_token",
                "eos_token",
                "unk_token",
                "sep_token",
                "pad_token",
                "cls_token",
                "mask_token",
                "additional_special_tokens",
            ]

            for (key, value) in context.model.tokenizerConfigs() where specialTokenAttributes.contains(key) {
                templateContext[key] = value
            }

            return try template.render(templateContext)
        } catch {
            throw .invalidParameter
        }
    }
}

public struct LlamaAutoMessageDecoder: LlamaChatMessageDecoder {
    var underlyingDecoder: any LlamaChatMessageDecoder = LlamaCustomMessageDecoder()

    init(context: Context) {
        guard let chatTemplate = context.model.chatTemplate, let template = try? Template(chatTemplate) else {
            return
        }

        do {
            let textMarker = "$TEXT$"
            let rendered = try template.render(["messages": [["role": "user", "content": [["type": "text", "text": textMarker]]]]])
            if rendered.contains("<|im_start|>"), rendered.contains(textMarker) {
                /*
                 {% set image_count = namespace(value=0) %}{% set video_count = namespace(value=0) %}{% for message in messages %}{% if loop.first and message['role'] != 'system' %}<|im_start|>system You are a helpful assistant.<|im_end|> {% endif %}<|im_start|>{{ message['role'] }} {% if message['content'] is string %}{{ message['content'] }}<|im_end|> {% else %}{% for content in message['content'] %}{% if content['type'] == 'image' or 'image' in content or 'image_url' in content %}{% set image_count.value = image_count.value + 1 %}{% if add_vision_id %}Picture {{ image_count.value }}: {% endif %}<|vision_start|><|image_pad|><|vision_end|>{% elif content['type'] == 'video' or 'video' in content %}{% set video_count.value = video_count.value + 1 %}{% if add_vision_id %}Video {{ video_count.value }}: {% endif %}<|vision_start|><|video_pad|><|vision_end|>{% elif 'text' in content %}{{ content['text'] }}{% endif %}{% endfor %}<|im_end|> {% endif %}{% endfor %}{% if add_generation_prompt %}<|im_start|>assistant {% endif %}
                 */
                underlyingDecoder = LlamaQwen2VLMessageDecoder()
            }
        } catch {}
    }

    public func templateValue(from messages: [LLMInput.Message]) -> [LLMInput.ChatTemplateMessage] {
        underlyingDecoder.templateValue(from: messages)
    }

    public func applyTemplate(_ messages: [LLMInput.ChatTemplateMessage], context: Context, additionalContext: [String: Any]?) throws(LLMError) -> String {
        try underlyingDecoder.applyTemplate(messages, context: context, additionalContext: additionalContext)
    }

    public func decode(_ messages: [LLMInput.ChatTemplateMessage], context: Context, clipModel: ClipModel?) throws -> DecodingContext {
        try underlyingDecoder.decode(messages, context: context, clipModel: clipModel)
    }
}

public struct LlamaCustomMessageDecoder: LlamaChatMessageDecoder {
    public init(
        tokenImageStart: String = "",
        tokenImageEnd: String = ""
    ) {
        self.tokenImageStart = tokenImageStart
        self.tokenImageEnd = tokenImageEnd
    }

    public let tokenImageStart: String
    public let tokenImageEnd: String

    public func decode(_ messages: [LLMInput.ChatTemplateMessage], context: Context, clipModel: ClipModel?) throws -> DecodingContext {
        let prompt = try applyTemplate(messages, context: context)
        let imagesChunks = messages.imageChunks()
        let pattern = try Regex("\(Regex<Void>(verbatim: tokenImageStart))(.*?)\(Regex<Void>(verbatim: tokenImageEnd))")

        var decodeContext = DecodingContext(cursor: 0, special: true)
        var lastIndex = prompt.startIndex
        var imageIndex = 0

        guard !tokenImageStart.isEmpty, !tokenImageEnd.isEmpty else {
            guard imagesChunks.isEmpty else { throw LLMError.decodingFailed }
            decodeContext = try context.decode(text: prompt, context: decodeContext)
            return decodeContext
        }

        for match in prompt.matches(of: pattern) {
            if lastIndex < match.range.lowerBound {
                let prefix = prompt[lastIndex..<match.range.lowerBound]
                decodeContext = try context.decode(text: String(prefix), context: decodeContext)
            }

            guard let clipModel else { throw LLMError.clipModelNotFound }
            guard imageIndex < imagesChunks.count else { throw LLMError.decodingFailed }

            for image in imagesChunks[imageIndex] {
                let embed = try clipModel.embedded(image: image)
                decodeContext = try context.decode(imageEmbed: embed, context: decodeContext)
            }
            imageIndex += 1

            lastIndex = match.range.upperBound
        }

        if lastIndex < prompt.endIndex {
            let suffix = prompt[lastIndex..<prompt.endIndex]
            decodeContext = try context.decode(text: String(suffix), context: decodeContext)
        }

        return decodeContext
    }
}

public struct LlamaQwen2VLMessageDecoder: LlamaChatMessageDecoder {
    public func templateValue(from messages: [LLMInput.Message]) -> [LLMInput.ChatTemplateMessage] {
        messages.map { message in
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
    
    public func decode(_ messages: [LLMInput.ChatTemplateMessage], context: Context, clipModel: ClipModel?) throws -> DecodingContext {
        let prompt = try applyTemplate(messages, context: context)
        let imagesChunks = messages.imageChunks()
        let pattern = /(?<image><|image_pad|>)|(?<video><|video_pad|>)/

        var decodeContext = DecodingContext(cursor: 0, special: true)
        var lastIndex = prompt.startIndex
        var imageIndex = 0

        for match in prompt.matches(of: pattern) {
            let prefix = prompt[lastIndex..<match.range.lowerBound]
            decodeContext = try context.decode(text: String(prefix), context: decodeContext)

            if let _ = match.output.image {
                guard let clipModel else { throw LLMError.clipModelNotFound }
                guard imageIndex < imagesChunks.count else { throw LLMError.decodingFailed }

                for image in imagesChunks[imageIndex] {
                    let embed = try clipModel.embedded(image: image)
                    decodeContext = try context.decode(imageEmbed: embed, context: decodeContext)
                }
                imageIndex += 1
            } else if let _ = match.output.video {
                // TODO: Handle video
            }

            lastIndex = match.range.upperBound
        }

        if lastIndex < prompt.endIndex {
            let suffix = prompt[lastIndex..<prompt.endIndex]
            decodeContext = try context.decode(text: String(suffix), context: decodeContext)
        }

        return decodeContext
    }

    enum Chunk {
        case text(String)
        case images([LLMInputImage])
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
            if case let .image(image) = attachment {
                return image
            }
            return nil
        }
    }
}
