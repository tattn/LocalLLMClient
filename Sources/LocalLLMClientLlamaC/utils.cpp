#include "include/utils.h"

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
