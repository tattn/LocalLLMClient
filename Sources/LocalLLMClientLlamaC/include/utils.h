#include <memory>

#include "../common/chat.h"

template<typename T, typename Deleter>
void* get_raw_pointer_from_unique_ptr(const std::unique_ptr<T, Deleter>& ptr);

struct common_chat_templates;
common_chat_templates* get_common_chat_templates(const common_chat_templates_ptr tmpls);

// Wrapper functions for Swift C++ interop
common_chat_templates_inputs* create_chat_templates_inputs();
void add_message_to_inputs(common_chat_templates_inputs* inputs, const char* role, const char* content);
void add_tool_to_inputs(common_chat_templates_inputs* inputs, const char* name, const char* description, const char* parameters_json);
common_chat_params apply_chat_templates_safe(const common_chat_templates* tmpls, common_chat_templates_inputs* inputs);
common_chat_params apply_chat_templates_with_model(const struct llama_model* model, common_chat_templates_inputs* inputs);
void free_chat_templates_inputs(common_chat_templates_inputs* inputs);

// Heap-allocated common_chat_params plus pre-built PEG arena.
// The `parser` string on common_chat_params is the serialized PEG grammar;
// callers need the deserialized common_peg_arena to run common_chat_parse.
// Keeping both together lets the model own a stable pointer Swift can retain.
struct llm_chat_params {
    common_chat_params        chat_params;
    common_chat_parser_params parser_params;
};

// Build a llm_chat_params from the model and a probing message set.
// Returns nullptr if the template cannot be applied.
llm_chat_params* create_chat_params(const struct llama_model* model, common_chat_templates_inputs* inputs);
void free_chat_params(llm_chat_params* params);
common_chat_format get_chat_params_format(const llm_chat_params* params);

// Parse a response using the pre-built parser params. Returns a message whose
// tool_calls vector is populated when the response matches the grammar.
common_chat_msg parse_chat_response(const llm_chat_params* params, const char* response, bool is_partial);
