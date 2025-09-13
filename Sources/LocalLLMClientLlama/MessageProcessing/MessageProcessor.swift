import LocalLLMClientCore
import Foundation
import Jinja

/// A modular message processor
public struct MessageProcessor: Sendable {
    private let transformer: MessageTransformer
    private let renderer: ChatTemplateRenderer
    private let chunkExtractor: MultimodalChunkExtractor
    private let llamaDecoder: LlamaSpecificDecoder
    
    init(
        transformer: MessageTransformer,
        renderer: ChatTemplateRenderer,
        chunkExtractor: MultimodalChunkExtractor,
        llamaDecoder: LlamaSpecificDecoder = StandardLlamaDecoder()
    ) {
        self.transformer = transformer
        self.renderer = renderer
        self.chunkExtractor = chunkExtractor
        self.llamaDecoder = llamaDecoder
    }
    
    /// Process messages end-to-end: transform, render, extract chunks, and decode
    public func process(
        messages: [LLMInput.Message],
        context: Context,
        multimodal: MultimodalContext?,
        tools: [AnyLLMTool] = []
    ) throws(LLMError) {
        // Step 1: Transform messages
        let templateMessages = transformer.transform(messages)
        
        // Step 2: Extract special tokens
        let specialTokens = llamaDecoder.extractSpecialTokens(from: context.model)
        let templateContext = TemplateContext(specialTokens: specialTokens)
        
        // Step 3: Render template
        let prompt = try renderer.render(
            messages: templateMessages,
            template: context.model.chatTemplate,
            context: templateContext,
            tools: tools
        )
        
        // Step 4: Extract chunks
        let imageChunks = extractImageChunks(from: templateMessages)
        let chunks = try chunkExtractor.extractChunks(
            from: prompt,
            imageChunks: imageChunks
        )
        
        // Step 5: Decode into context
        try llamaDecoder.decode(
            chunks: chunks,
            context: context,
            multimodal: multimodal
        )
    }
    
    /// Process pre-transformed template messages
    public func process(
        templateMessages: [LLMInput.ChatTemplateMessage],
        context: Context,
        multimodal: MultimodalContext?,
        tools: [AnyLLMTool] = []
    ) throws(LLMError) {
        // Skip transformation step when messages are already in template format
        let specialTokens = llamaDecoder.extractSpecialTokens(from: context.model)
        let templateContext = TemplateContext(specialTokens: specialTokens)
        
        let prompt = try renderer.render(
            messages: templateMessages,
            template: context.model.chatTemplate,
            context: templateContext,
            tools: tools
        )
        
        let imageChunks = extractImageChunks(from: templateMessages)
        let chunks = try chunkExtractor.extractChunks(
            from: prompt,
            imageChunks: imageChunks
        )
        
        try llamaDecoder.decode(
            chunks: chunks,
            context: context,
            multimodal: multimodal
        )
    }
    
    /// Get the rendered prompt without decoding (useful for debugging)
    public func renderPrompt(
        messages: [LLMInput.Message],
        template: String,
        tools: [AnyLLMTool] = []
    ) throws(LLMError) -> String {
        let templateMessages = transformer.transform(messages)
        return try renderer.render(
            messages: templateMessages,
            template: template,
            context: TemplateContext(),
            tools: tools
        )
    }
    
    private func extractImageChunks(from messages: [LLMInput.ChatTemplateMessage]) -> [[LLMInputImage]] {
        messages.compactMap { message in
            let images = message.attachments.compactMap { attachment -> LLMInputImage? in
                if case let .image(image) = attachment.content {
                    return image
                }
                return nil
            }
            return images.isEmpty ? nil : images
        }
    }
}

// MARK: - Testing Support
#if DEBUG
extension MessageProcessor {
    /// Test helper to render and extract chunks without requiring a full Context
    func renderAndExtractChunks(
        messages: [LLMInput.Message],
        template: String,
        specialTokens: [String: String] = [:],
        tools: [AnyLLMTool] = []
    ) throws(LLMError) -> (rendered: String, chunks: [MessageChunk]) {
        let templateMessages = transformer.transform(messages)
        let templateContext = TemplateContext(specialTokens: specialTokens)
        
        let rendered = try renderer.render(
            messages: templateMessages,
            template: template,
            context: templateContext,
            tools: tools
        )
        
        let imageChunks = extractImageChunks(from: templateMessages)
        let chunks = try chunkExtractor.extractChunks(
            from: rendered,
            imageChunks: imageChunks
        )
        
        return (rendered, chunks)
    }
}
#endif

/// Factory for creating message processors with appropriate components
public struct MessageProcessorFactory {
    
    /// Create a processor for Qwen2VL models
    public static func qwen2VLProcessor() -> MessageProcessor {
        MessageProcessor(
            transformer: StandardMessageTransformer(),
            renderer: JinjaChatTemplateRenderer(),
            chunkExtractor: Qwen2VLChunkExtractor()
        )
    }
    
    /// Create a processor for Llama 3.2 Vision models
    public static func llama32VisionProcessor() -> MessageProcessor {
        MessageProcessor(
            transformer: RoleBasedMessageTransformer(),
            renderer: JinjaChatTemplateRenderer(),
            chunkExtractor: Llama32VisionChunkExtractor()
        )
    }
    
    /// Create a processor for ChatML format
    public static func chatMLProcessor() -> MessageProcessor {
        MessageProcessor(
            transformer: ChatMLMessageTransformer(),
            renderer: JinjaChatTemplateRenderer(),
            chunkExtractor: TextOnlyChunkExtractor()
        )
    }
    
    /// Create a processor for Gemma3 models
    public static func gemma3Processor() -> MessageProcessor {
        MessageProcessor(
            transformer: StandardMessageTransformer(),
            renderer: JinjaChatTemplateRenderer(),
            chunkExtractor: RegexChunkExtractor(imageTokenPattern: "<start_of_image>")
        )
    }
    
    /// Create a processor for SmolVLM models  
    public static func smolVLMProcessor() -> MessageProcessor {
        MessageProcessor(
            transformer: StandardMessageTransformer(),
            renderer: JinjaChatTemplateRenderer(),
            chunkExtractor: RegexChunkExtractor(imageTokenPattern: "<image>")
        )
    }
    
    /// Create an auto-detecting processor based on chat template
    public static func createAutoProcessor(chatTemplate: String) -> MessageProcessor {
        // Check for specific template patterns
        if chatTemplate.contains("<|im_start|>") && chatTemplate.contains("<end_of_utterance>") {
            // SmolVLM format
            return smolVLMProcessor()
        } else if chatTemplate.contains("content[i].type == 'image'") || chatTemplate.contains("<vision>") {
            // Qwen2VL format
            return qwen2VLProcessor()
        } else if chatTemplate.contains("<|begin_of_text|>") && chatTemplate.contains("<|start_header_id|>") {
            // Llama 3.2 Vision format
            return llama32VisionProcessor()
        } else if chatTemplate.contains("<start_of_image>") {
            // Gemma3 format
            return gemma3Processor()
        } else if chatTemplate.contains("<|im_start|>") || chatTemplate.contains("<|endoftext|>") {
            // ChatML format (Phi4 and others)
            return chatMLProcessor()
        }
        
        // Fallback to ChatML if no specific pattern is found
        return chatMLProcessor()
    }
}
