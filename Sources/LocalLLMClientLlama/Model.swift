import Foundation
import LocalLLMClientCore
import LocalLLMClientLlamaC
import Jinja

final class Model {
    let model: OpaquePointer
    let chatTemplate: String

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

        let chatTemplate = getString(capacity: 4096) { buffer, length in
            // LLM_KV_TOKENIZER_CHAT_TEMPLATE
            llama_model_meta_val_str(model, "tokenizer.chat_template", buffer, length)
        }

        // If the template is empty, it uses Gemma3-styled template as default
        self.chatTemplate = chatTemplate.isEmpty ? #"{{ bos_token }} {%- if messages[0]['role'] == 'system' -%} {%- if messages[0]['content'] is string -%} {%- set first_user_prefix = messages[0]['content'] + ' ' -%} {%- else -%} {%- set first_user_prefix = messages[0]['content'][0]['text'] + ' ' -%} {%- endif -%} {%- set loop_messages = messages[1:] -%} {%- else -%} {%- set first_user_prefix = "" -%} {%- set loop_messages = messages -%} {%- endif -%} {%- for message in loop_messages -%} {%- if (message['role'] == 'user') != (loop.index0 % 2 == 0) -%} {{ raise_exception("Conversation roles must alternate user/assistant/user/assistant/...") }} {%- endif -%} {%- if (message['role'] == 'assistant') -%} {%- set role = "model" -%} {%- else -%} {%- set role = message['role'] -%} {%- endif -%} {{ (first_user_prefix if loop.first else "") }} {%- if message['content'] is string -%} {{ message['content'] | trim }} {%- elif message['content'] is iterable -%} {%- for item in message['content'] -%} {%- if item['type'] == 'image' -%} {{ '<start_of_image>' }} {%- elif item['type'] == 'text' -%} {{ item['text'] | trim }} {%- endif -%} {%- endfor -%} {%- else -%} {{ raise_exception("Invalid content type") }} {%- endif -%} {%- endfor -%}"# : chatTemplate
    }

    deinit {
        llama_model_free(model)
    }

    func makeAndAllocateContext(with ctx_params: llama_context_params) throws(LLMError) -> OpaquePointer {
        guard let context = llama_init_from_model(model, ctx_params) else {
            throw .invalidParameter(reason: "Failed to create context")
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

    func chatFormat() -> common_chat_format {
        let inputs = create_chat_templates_inputs()
        defer { 
            free_chat_templates_inputs(inputs)
        }

        add_message_to_inputs(inputs, "user", "test")
        let params = apply_chat_templates_with_model(model, inputs)
        return params.format
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
