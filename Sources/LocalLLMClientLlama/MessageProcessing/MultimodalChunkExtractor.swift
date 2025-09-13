import LocalLLMClientCore
import Foundation

/// Protocol for extracting multimodal chunks from rendered prompts
protocol MultimodalChunkExtractor: Sendable {
    /// Extract chunks from a prompt with associated images
    func extractChunks(
        from prompt: String,
        imageChunks: [[LLMInputImage]]
    ) throws(LLMError) -> [MessageChunk]
}

/// Regex-based chunk extractor for custom image tokens
struct RegexChunkExtractor: MultimodalChunkExtractor {
    private let imageTokenPattern: String
    
    init(imageTokenPattern: String = "<start_of_image>") {
        self.imageTokenPattern = imageTokenPattern
    }
    
    func extractChunks(
        from prompt: String,
        imageChunks: [[LLMInputImage]]
    ) throws(LLMError) -> [MessageChunk] {
        let pattern: Regex<Substring>
        do {
            pattern = try Regex<Substring>(imageTokenPattern)
        } catch {
            throw LLMError.invalidParameter(reason: "Invalid regex pattern: \(error.localizedDescription)")
        }
        var chunks: [MessageChunk] = []
        var lastIndex = prompt.startIndex
        var imageIndex = 0
        
        for match in prompt.matches(of: pattern) {
            // Add text before the match
            if lastIndex < match.range.lowerBound {
                let prefix = prompt[lastIndex..<match.range.lowerBound]
                chunks.append(.text(String(prefix)))
            }
            
            // Add image chunk
            if imageIndex < imageChunks.count {
                chunks.append(.image(imageChunks[imageIndex]))
                imageIndex += 1
            }
            
            lastIndex = match.range.upperBound
        }
        
        // Add remaining text
        if lastIndex < prompt.endIndex {
            let suffix = prompt[lastIndex..<prompt.endIndex]
            chunks.append(.text(String(suffix)))
        }
        
        return chunks
    }
}

/// Chunk extractor for Qwen2VL models with image and video support
struct Qwen2VLChunkExtractor: MultimodalChunkExtractor {
    init() {}
    
    func extractChunks(
        from prompt: String,
        imageChunks: [[LLMInputImage]]
    ) throws(LLMError) -> [MessageChunk] {
        let pattern = /(?<image><\|image_pad\|>)|(?<video><\|video_pad\|>)/
        var chunks = [MessageChunk]()
        var lastIndex = prompt.startIndex
        var imageIndex = 0
        
        for match in prompt.matches(of: pattern) {
            // Add text before the match
            if lastIndex < match.range.lowerBound {
                let prefix = prompt[lastIndex..<match.range.lowerBound]
                chunks.append(.text(String(prefix)))
            }
            
            // Add image or video chunk
            if let _ = match.output.image {
                guard imageIndex < imageChunks.count else {
                    throw LLMError.failedToDecode(reason: "Not enough image chunks for image token at position \(imageIndex)")
                }
                chunks.append(.image(imageChunks[imageIndex]))
                imageIndex += 1
            } else if let _ = match.output.video {
                // TODO: Handle video chunks when video support is added
                chunks.append(.video([]))
            }
            
            lastIndex = match.range.upperBound
        }
        
        // Add remaining text
        if lastIndex < prompt.endIndex {
            let suffix = prompt[lastIndex..<prompt.endIndex]
            chunks.append(.text(String(suffix)))
        }
        
        return chunks
    }
}

/// Chunk extractor for Llama 3.2 Vision models
struct Llama32VisionChunkExtractor: MultimodalChunkExtractor {
    init() {}
    
    func extractChunks(
        from prompt: String,
        imageChunks: [[LLMInputImage]]
    ) throws(LLMError) -> [MessageChunk] {
        let extractor = RegexChunkExtractor(imageTokenPattern: #"<\|image\|>"#)
        return try extractor.extractChunks(from: prompt, imageChunks: imageChunks)
    }
}

/// Simple text-only chunk extractor (no multimodal content)
struct TextOnlyChunkExtractor: MultimodalChunkExtractor {
    init() {}
    
    func extractChunks(
        from prompt: String,
        imageChunks: [[LLMInputImage]]
    ) throws(LLMError) -> [MessageChunk] {
        [.text(prompt)]
    }
}

