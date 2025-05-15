#if BUILD_DOCC
@preconcurrency @_implementationOnly import llama
#else
@preconcurrency private import llama
#endif
import Foundation
import LocalLLMClient
import os.lock

public final class Context: @unchecked Sendable {
    let parameter: LlamaClient.Parameter
    package let context: OpaquePointer
    package var batch: llama_batch
    var sampling: Sampler
    let grammer: Sampler?
    var cursor: [llama_token_data]
    let model: Model
    let extraEOSTokens: Set<String>

    package var vocab: OpaquePointer {
        model.vocab
    }

    package var numberOfBatch: Int32 {
        Int32(llama_n_batch(context))
    }

    package var position: Int32 {
        llama_kv_self_used_cells(context)
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
        llama_sampler_chain_add(sampling, llama_sampler_init_dist(LLAMA_DEFAULT_SEED))
        llama_sampler_chain_add(sampling, llama_sampler_init_top_k(Int32(parameter.topK)))
        llama_sampler_chain_add(sampling, llama_sampler_init_top_p(parameter.topP, minKeep))
        llama_sampler_chain_add(sampling, llama_sampler_init_min_p(1 - parameter.topP, 1))
        llama_sampler_chain_add(sampling, llama_sampler_init_typical(parameter.typicalP, minKeep))
        llama_sampler_chain_add(sampling, llama_sampler_init_penalties(Int32(parameter.penaltyLastN), parameter.penaltyRepeat, penaltyFreq, penaltyPresent))

        let cursorCount = Int(llama_vocab_n_tokens(model.vocab))
        cursor = Array(unsafeUninitializedCapacity: cursorCount) { _, initializedCount in
            initializedCount = cursorCount
        }

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
        llama_sampler_free(sampling)
        llama_batch_free(batch)
        llama_free(context)
    }

    public func clear() {
        llama_kv_self_clear(context)
    }
}
