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
    let pauseHandler: PauseHandler

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

        // Flash Attention — significantly faster on Apple Silicon and uses
        // less attention-buffer memory. llama.cpp `b8851` exposes this as a
        // tri-state enum (auto / disabled / enabled). We map our boolean to
        // explicit enabled/disabled so behavior is deterministic.
        ctx_params.flash_attn_type = parameter.flashAttention
            ? LLAMA_FLASH_ATTN_TYPE_ENABLED
            : LLAMA_FLASH_ATTN_TYPE_DISABLED

        // KV cache quantization. Lower precision halves (or quarters) the
        // memory cost of the cache, which scales linearly with `n_ctx`.
        // `f16` keeps full precision (default); `q8_0` and `q4_0` trade a
        // small amount of quality for substantial memory savings.
        ctx_params.type_k = Self.ggmlType(for: parameter.kvCacheTypeK)
        ctx_params.type_v = Self.ggmlType(for: parameter.kvCacheTypeV)

        self.parameter = parameter
        self.pauseHandler = PauseHandler(disableAutoPause: parameter.options.disableAutoPause)
        self.model = try Model(url: url, parameter: parameter)
        self.context = try model.makeAndAllocateContext(with: ctx_params)
        batch = llama_batch_init(Int32(parameter.batch), 0, 1)
        extraEOSTokens = parameter.options.extraEOSTokens

        // https://github.com/ggml-org/llama.cpp/blob/master/common/sampling.cpp
        sampling = llama_sampler_chain_init(llama_sampler_chain_default_params())

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

        let minKeep = 0
        let penaltyFreq: Float = 0
        let penaltyPresent: Float = 0
        llama_sampler_chain_add(sampling, llama_sampler_init_temp_ext(parameter.temperature, 0, 1.0))
        llama_sampler_chain_add(sampling, llama_sampler_init_top_k(Int32(parameter.topK)))
        llama_sampler_chain_add(sampling, llama_sampler_init_top_p(parameter.topP, minKeep))
        llama_sampler_chain_add(sampling, llama_sampler_init_min_p(1 - parameter.topP, 1))
        llama_sampler_chain_add(sampling, llama_sampler_init_typical(parameter.typicalP, minKeep))
        llama_sampler_chain_add(sampling, llama_sampler_init_penalties(Int32(parameter.penaltyLastN), parameter.penaltyRepeat, penaltyFreq, penaltyPresent))
        llama_sampler_chain_add(sampling, llama_sampler_init_dist(parameter.seed.map(UInt32.init) ?? LLAMA_DEFAULT_SEED))

        cursorPointer = .allocate(capacity: Int(llama_vocab_n_tokens(model.vocab)))
    }

    deinit {
        cursorPointer.deallocate()
        llama_sampler_free(sampling)
        llama_batch_free(batch)
        llama_free(context)
    }

    /// Maps the public Swift KV cache type enum to the underlying GGML type.
    private static func ggmlType(for type: LlamaClient.KVCacheType) -> ggml_type {
        switch type {
        case .f16:  return GGML_TYPE_F16
        case .q8_0: return GGML_TYPE_Q8_0
        case .q4_0: return GGML_TYPE_Q4_0
        }
    }

    public func clear() {
        // Reset the prefill batch as well as the KV cache. Without this, a
        // generation that was cut short by an external stop condition (e.g.
        // stop sequences applied at the consumer level) leaves
        // `batch.n_tokens > 0` because the generator's per-token `batch.add`
        // is followed by an early `break` in the consumer's `for try await`,
        // skipping the next `decode()` that would have called `batch.clear()`.
        // The next `textStream(...)` call's prefill then walks past the end
        // of the batch's `seq_id` array (allocated for `parameter.batch`
        // entries) and crashes on a force-unwrap of nil. Clearing the batch
        // here makes `clear()` safe to call between any two generations.
        batch.clear()

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
