import LocalLLMClientCore
import Foundation

/// Protocol for llama.cpp-specific decoding operations
protocol LlamaSpecificDecoder: Sendable {
    /// Extract special tokens from the model vocabulary
    func extractSpecialTokens(from model: Model) -> [String: String]
    
    /// Decode chunks into the llama context
    func decode(
        chunks: [MessageChunk],
        context: Context,
        multimodal: MultimodalContext?
    ) throws(LLMError)
}

/// Standard implementation of llama-specific decoding
struct StandardLlamaDecoder: LlamaSpecificDecoder {
    init() {}
    
    func extractSpecialTokens(from model: Model) -> [String: String] {
        [
            "bos_token": getTokenText(model.vocab, tokenId: max(0, llama_vocab_bos(model.vocab))),
            "eos_token": getTokenText(model.vocab, tokenId: max(0, llama_vocab_eos(model.vocab))),
            "unk_token": getTokenText(model.vocab, tokenId: 0),
            "sep_token": getTokenText(model.vocab, tokenId: max(0, llama_vocab_sep(model.vocab))),
            "pad_token": getTokenText(model.vocab, tokenId: max(0, llama_vocab_pad(model.vocab))),
            "cls_token": getTokenText(model.vocab, tokenId: max(0, llama_vocab_bos(model.vocab))),
            "mask_token": ""
        ]
    }
    
    func decode(
        chunks: [MessageChunk],
        context: Context,
        multimodal: MultimodalContext?
    ) throws(LLMError) {
        // Filter chunks based on cache
        var chunksToProcess = chunks
        context.removeCachedChunks(&chunksToProcess)
        
        // Process each chunk
        for chunk in chunksToProcess {
            try processChunk(chunk, context: context, multimodal: multimodal)
            
            // Add to cache after successful processing
            context.addCache(for: chunk, position: context.position)
        }
    }
    
    private func getTokenText(_ vocab: OpaquePointer, tokenId: Int32) -> String {
        String(utf8String: llama_vocab_get_text(vocab, tokenId)) ?? ""
    }
    
    private func processChunk(
        _ chunk: MessageChunk,
        context: Context,
        multimodal: MultimodalContext?
    ) throws(LLMError) {
        switch chunk {
        case .text(let text):
            try context.decode(text: text)
            
        case .image(let images):
            guard let multimodal else {
                throw LLMError.failedToDecode(reason: "Multimodal context required for image decoding")
            }
            let bitmap = try multimodal.chunks(images: images)
            try context.decode(bitmap: bitmap, with: multimodal)
            
        case .video:
            // Video support not yet implemented
            throw LLMError.failedToDecode(reason: "Video decoding not yet supported")
        }
    }
}
