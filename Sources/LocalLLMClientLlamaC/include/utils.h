#include <memory>

#include "../common/chat.h"

template<typename T, typename Deleter>
void* get_raw_pointer_from_unique_ptr(const std::unique_ptr<T, Deleter>& ptr);

struct common_chat_templates;
common_chat_templates* get_common_chat_templates(const common_chat_templates_ptr tmpls);

// Wrapper functions for Swift C++ interop
common_chat_templates_inputs* create_chat_templates_inputs();
void add_message_to_inputs(common_chat_templates_inputs* inputs, const char* role, const char* content);
common_chat_params apply_chat_templates_safe(const common_chat_templates* tmpls, common_chat_templates_inputs* inputs);
common_chat_params apply_chat_templates_with_model(const struct llama_model* model, common_chat_templates_inputs* inputs);
void free_chat_templates_inputs(common_chat_templates_inputs* inputs);
