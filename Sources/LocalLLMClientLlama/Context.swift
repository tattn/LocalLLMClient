#if BUILD_DOCC
@preconcurrency @_implementationOnly import llama
#elseif canImport(llama)
@preconcurrency private import llama
#else
@preconcurrency import LocalLLMClientLlamaC
#endif
import Foundation
import LocalLLMClientCore

public final class Context: @unchecked Sendable {
    let parameter: LlamaClient.Parameter
    package let context: OpaquePointer
    package var batch: llama_batch
    var sampling: Sampler
    let grammer: Sampler?
    let cursorPointer: UnsafeMutableBufferPointer<llama_token_data>
    let model: Model
    let extraEOSTokens: Set<String>
    private var promptCaches: [(chunk: MessageChunk, lastPosition: llama_pos)] = []

    package var vocab: OpaquePointer {
        model.vocab
    }

    package var numberOfBatch: Int32 {
        Int32(llama_n_batch(context))
    }

    package var position: Int32 {
        guard let kv = llama_get_memory(context) else {
            return -1
        }

        return llama_memory_seq_pos_max(kv, 0) + 1
    }

    public init(url: URL, parameter: LlamaClient.Parameter = .default) throws(LLMError) {
        initializeLlama()

        var ctx_params = llama_context_default_params()
        ctx_params.n_ctx = UInt32(parameter.context)
        ctx_params.n_threads = Int32(parameter.numberOfThreads ?? max(1, min(8, ProcessInfo.processInfo.processorCount - 2)))
        ctx_params.n_threads_batch = ctx_params.n_threads

        self.parameter = parameter
        self.model = try Model(url: url)
        self.context = try model.makeAndAllocateContext(with: ctx_params)
        batch = llama_batch_init(Int32(parameter.batch), 0, 1)
        extraEOSTokens = parameter.options.extraEOSTokens

        // https://github.com/ggml-org/llama.cpp/blob/master/common/sampling.cpp
        sampling = llama_sampler_chain_init(llama_sampler_chain_default_params())
        let minKeep = 0
        let penaltyFreq: Float = 0
        let penaltyPresent: Float = 0
        llama_sampler_chain_add(sampling, llama_sampler_init_temp(parameter.temperature))
        llama_sampler_chain_add(sampling, llama_sampler_init_dist(parameter.seed.map(UInt32.init) ?? LLAMA_DEFAULT_SEED))
        llama_sampler_chain_add(sampling, llama_sampler_init_top_k(Int32(parameter.topK)))
        llama_sampler_chain_add(sampling, llama_sampler_init_top_p(parameter.topP, minKeep))
        llama_sampler_chain_add(sampling, llama_sampler_init_min_p(1 - parameter.topP, 1))
        llama_sampler_chain_add(sampling, llama_sampler_init_typical(parameter.typicalP, minKeep))
        llama_sampler_chain_add(sampling, llama_sampler_init_penalties(Int32(parameter.penaltyLastN), parameter.penaltyRepeat, penaltyFreq, penaltyPresent))

        cursorPointer = .allocate(capacity: Int(llama_vocab_n_tokens(model.vocab)))

        if let format = parameter.options.responseFormat {
            switch format {
            case .json:
                do {
                    let template = try String(contentsOf: Bundle.module.url(forResource: "json", withExtension: "gbnf")!, encoding: .utf8)
                    grammer = llama_sampler_init_grammar(model.vocab, template, "root")
                } catch {
                    throw .failedToLoad(reason: "Failed to load grammar template")
                }
            case let .grammar(grammar, root):
                grammer = llama_sampler_init_grammar(model.vocab, grammar, root)
            }
            llama_sampler_chain_add(sampling, grammer)
        } else {
            grammer = nil
        }
    }

    deinit {
        cursorPointer.deallocate()
        llama_sampler_free(sampling)
        llama_batch_free(batch)
        llama_free(context)
    }

    public func clear() {
        guard let kv = llama_get_memory(context) else {
            return
        }

        llama_memory_clear(kv, true)
    }

    func addCache(for chunk: MessageChunk, position: llama_pos) {
        let endIndex = promptCaches.endIndex - 1
        switch (chunk, promptCaches.last?.chunk) {
        case let (.text(chunkText), .text(cacheText)):
            promptCaches[endIndex] = (chunk: .text(cacheText + chunkText), lastPosition: position)
        case let (.image(chunkImages), .image(cacheImages)):
            promptCaches[endIndex] = (chunk: .image(cacheImages + chunkImages), lastPosition: position)
        case let (.video(chunkVideos), .video(cacheVideos)):
            promptCaches[endIndex] = (chunk: .video(cacheVideos + chunkVideos), lastPosition: position)
        default:
            promptCaches.append((chunk: chunk, lastPosition: position))
        }
    }

    func removeCachedChunks(_ chunks: inout [MessageChunk]) {
        guard let (lastCacheIndex, newChunk) = lastCacheIndex(of: chunks) else {
            return
        }
        chunks = Array(chunks[(lastCacheIndex + 1)...])
        if let newChunk {
            chunks.append(newChunk)
        }
        if promptCaches[lastCacheIndex].lastPosition < position,
           let kv = llama_get_memory(context) {
            assert(llama_memory_seq_rm(kv, 0, promptCaches[lastCacheIndex].lastPosition, position))
        }
        if promptCaches.count > lastCacheIndex {
            promptCaches.removeSubrange((lastCacheIndex + 1)...)
        }
    }

    func lastCacheIndex(of chunks: [MessageChunk]) -> (index: Int, remaining: MessageChunk?)? {
        for (index, (chunk, cache)) in zip(chunks, promptCaches).enumerated() {
            switch (chunk, cache.chunk) {
            case let (.text(chunkText), .text(cacheText)) where chunkText.hasPrefix(cacheText):
                if chunkText == cacheText {
                    return (index, nil)
                } else {
                    return (index, .text(String(chunkText.dropFirst(cacheText.count))))
                }
            case let (.image(chunkImages), .image(cacheImages)) where chunkImages == cacheImages:
                return (index, nil)
            case let (.video(chunkVideos), .video(cacheVideos)) where chunkVideos == cacheVideos:
                return (index, nil)
            default:
                break
            }
        }
        return nil
    }
}
