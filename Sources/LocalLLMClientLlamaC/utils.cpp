#include "include/utils.h"

#include <cstdio>

template<typename T, typename Deleter>
void* get_raw_pointer_from_unique_ptr(const std::unique_ptr<T, Deleter>& ptr) {
    return static_cast<void*>(ptr.get());
}

common_chat_templates* get_common_chat_templates(const common_chat_templates_ptr tmpls) {
    return tmpls.get();
}

// Wrapper functions for Swift C++ interop
common_chat_templates_inputs* create_chat_templates_inputs() {
    auto* inputs = new common_chat_templates_inputs();
    inputs->add_generation_prompt = true;
    inputs->use_jinja = true;
    return inputs;
}

void add_message_to_inputs(common_chat_templates_inputs* inputs, const char* role, const char* content) {
    if (inputs && role && content) {
        common_chat_msg msg;
        msg.role = std::string(role);
        msg.content = std::string(content);
        inputs->messages.push_back(msg);
    }
}

void add_tool_to_inputs(common_chat_templates_inputs* inputs, const char* name, const char* description, const char* parameters_json) {
    if (inputs && name) {
        common_chat_tool tool;
        tool.name        = std::string(name);
        tool.description = description ? std::string(description) : std::string();
        tool.parameters  = parameters_json ? std::string(parameters_json) : std::string("{}");
        inputs->tools.push_back(std::move(tool));
    }
}

common_chat_params apply_chat_templates_safe(const common_chat_templates* tmpls, common_chat_templates_inputs* inputs) {
    if (tmpls && inputs) {
        return common_chat_templates_apply(tmpls, *inputs);
    }
    return {};
}

common_chat_params apply_chat_templates_with_model(const struct llama_model* model, common_chat_templates_inputs* inputs) {
    if (model && inputs) {
        auto templates = common_chat_templates_init(model, "", "", "");
        if (templates) {
            return common_chat_templates_apply(templates.get(), *inputs);
        }
    }
    return {};
}

void free_chat_templates_inputs(common_chat_templates_inputs* inputs) {
    delete inputs;
}

llm_chat_params* create_chat_params(const struct llama_model* model, common_chat_templates_inputs* inputs) {
    if (!model || !inputs) {
        return nullptr;
    }
    auto templates = common_chat_templates_init(model, "", "", "");
    if (!templates) {
        return nullptr;
    }
    auto* out = new llm_chat_params{};
    out->chat_params = common_chat_templates_apply(templates.get(), *inputs);
    out->parser_params = common_chat_parser_params(out->chat_params);
    if (!out->chat_params.parser.empty()) {
        out->parser_params.parser.load(out->chat_params.parser);
    }
    return out;
}

void free_chat_params(llm_chat_params* params) {
    delete params;
}

common_chat_format get_chat_params_format(const llm_chat_params* params) {
    return params ? params->chat_params.format : COMMON_CHAT_FORMAT_CONTENT_ONLY;
}

common_chat_msg parse_chat_response(const llm_chat_params* params, const char* response, bool is_partial) {
    if (!params || !response) {
        return {};
    }
    try {
        return common_chat_parse(response, is_partial, params->parser_params);
    } catch (const std::exception & e) {
        // Grammar-mismatched input throws from the PEG parser. Treat it as "no
        // tool calls" but surface the reason on stderr so genuine errors
        // (allocation failure, invariant violations, ...) remain diagnosable.
        fprintf(stderr, "[LocalLLMClient] parse_chat_response: %s\n", e.what());
        return {};
    }
}
