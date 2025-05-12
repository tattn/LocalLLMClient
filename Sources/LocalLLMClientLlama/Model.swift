import Foundation
import LocalLLMClient
import Jinja

final class Model {
    let model: OpaquePointer
    let chatTemplate: String?

    var vocab: OpaquePointer {
        llama_model_get_vocab(model)
    }

    init(url: URL) throws(LLMError) {
        var model_params = llama_model_default_params()
#if targetEnvironment(simulator)
        model_params.n_gpu_layers = 0
#endif
        model_params.use_mmap = true

        guard let model = llama_model_load_from_file(url.path(), model_params) else {
            throw .failedToLoad(reason: "Failed to load model from file")
        }

        self.model = model

        let chatTemplate = getString(capacity: 2048) { buffer, length in
            // LLM_KV_TOKENIZER_CHAT_TEMPLATE
            llama_model_meta_val_str(model, "tokenizer.chat_template", buffer, length)
        }
        self.chatTemplate = chatTemplate.isEmpty ? nil : chatTemplate
    }

    deinit {
        llama_model_free(model)
    }

    func makeAndAllocateContext(with ctx_params: llama_context_params) throws(LLMError) -> OpaquePointer {
        guard let context = llama_init_from_model(model, ctx_params) else {
            throw .invalidParameter
        }
        return context
    }

    func tokenizerConfigs() -> [String: Any] {
        let numberOfConfigs = llama_model_meta_count(model)
        return (0..<numberOfConfigs).reduce(into: [:]) { partialResult, i in
            let key = getString(capacity: 64) { buffer, length in
                llama_model_meta_key_by_index(model, i, buffer, length)
            }
            let value = getString(capacity: 2048) { buffer, length in
                llama_model_meta_val_str_by_index(model, i, buffer, length)
            }
            partialResult[key] = value
        }
    }
}

private func getString(capacity: Int = 1024, getter: (UnsafeMutablePointer<CChar>?, Int) -> Int32) -> String {
    String(unsafeUninitializedCapacity: capacity) { buffer in
        buffer.withMemoryRebound(to: CChar.self) { buffer in
            let length = Int(getter(buffer.baseAddress, capacity))
            return max(0, length)
        }
    }
}
