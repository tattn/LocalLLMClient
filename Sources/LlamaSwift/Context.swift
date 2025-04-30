@preconcurrency import llama
import Foundation
import LLMCommon

public final class Context {
    let parameter: LLMParameter
    package let context: OpaquePointer
    package var batch: llama_batch
    var sampling: Sampler
    var cursor: [llama_token_data]
    private let model: OpaquePointer

    package var vocab: OpaquePointer {
        llama_model_get_vocab(model)
    }

    package var addBos: Bool {
        llama_vocab_get_add_bos(vocab)
    }

    package var numberOfBatch: Int32 {
        Int32(llama_n_batch(context))
    }

    public init(url: URL, parameter: LLMParameter = .default) throws(LLMError) {
        initializeLlama()

        var model_params = llama_model_default_params()
#if targetEnvironment(simulator)
        model_params.n_gpu_layers = 0
#endif
        model_params.use_mmap = true

        guard let model = llama_model_load_from_file(url.path(), model_params) else {
            throw .failedToLoad
        }

        var ctx_params = llama_context_default_params()
        ctx_params.n_ctx = UInt32(parameter.context)
        ctx_params.n_threads = Int32(parameter.numberOfThreads ?? max(1, min(8, ProcessInfo.processInfo.processorCount - 2)))
        ctx_params.n_threads_batch = ctx_params.n_threads

        guard let context = llama_init_from_model(model, ctx_params) else {
            throw .invalidParameter
        }

        self.parameter = parameter
        self.model = model
        self.context = context
        batch = llama_batch_init(Int32(parameter.batch), 0, 1)

        // https://github.com/ggml-org/llama.cpp/blob/master/common/sampling.cpp
        sampling = llama_sampler_chain_init(llama_sampler_chain_default_params())
        let minKeep = 0
        llama_sampler_chain_add(sampling, llama_sampler_init_temp(parameter.temperature))
        llama_sampler_chain_add(sampling, llama_sampler_init_dist(LLAMA_DEFAULT_SEED))
        llama_sampler_chain_add(sampling, llama_sampler_init_top_k(Int32(parameter.topK)))
        llama_sampler_chain_add(sampling, llama_sampler_init_top_p(parameter.topP, minKeep))
        llama_sampler_chain_add(sampling, llama_sampler_init_typical(parameter.typicalP, minKeep))
        llama_sampler_chain_add(sampling, llama_sampler_init_penalties(Int32(parameter.penaltyLastN), parameter.penaltyRepeat, 0, 0))

        let cursorCount = Int(llama_vocab_n_tokens(llama_model_get_vocab(model)))
        cursor = Array(unsafeUninitializedCapacity: cursorCount) { _, initializedCount in
            initializedCount = cursorCount
        }
    }

    deinit {
        llama_sampler_free(sampling)
        llama_batch_free(batch)
        llama_model_free(model)
        llama_free(context)
    }
}
