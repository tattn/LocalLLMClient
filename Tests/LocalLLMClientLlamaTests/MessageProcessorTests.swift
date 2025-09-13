import Testing
import Foundation
import LocalLLMClientCore
@testable import LocalLLMClientLlama

private let systemMarker = "$$SYSTEM$$"
private let userMarker = "$$USER$$"
private let assistantMarker = "$$ASSISTANT$$"

@Suite(.disabled(if: disabledTests))
struct MessageProcessorTests {
    @Test
    func qwen2_5_VL() async throws {
        // https://huggingface.co/ggml-org/Qwen2.5-VL-7B-Instruct-GGUF
        let template = #"{% set image_count = namespace(value=0) %}{% set video_count = namespace(value=0) %}{% for message in messages %}{% if loop.first and message['role'] != 'system' %}<|im_start|>system You are a helpful assistant.<|im_end|> {% endif %}<|im_start|>{{ message['role'] }} {% if message['content'] is string %}{{ message['content'] }}<|im_end|> {% else %}{% for content in message['content'] %}{% if content['type'] == 'image' or 'image' in content or 'image_url' in content %}{% set image_count.value = image_count.value + 1 %}{% if add_vision_id %}Picture {{ image_count.value }}: {% endif %}<|vision_start|><|image_pad|><|vision_end|>{% elif content['type'] == 'video' or 'video' in content %}{% set video_count.value = video_count.value + 1 %}{% if add_vision_id %}Video {{ video_count.value }}: {% endif %}<|vision_start|><|video_pad|><|vision_end|>{% elif 'text' in content %}{{ content['text'] }}{% endif %}{% endfor %}<|im_end|> {% endif %}{% endfor %}{% if add_generation_prompt %}<|im_start|>assistant {% endif %}"#
        let processor = MessageProcessorFactory.qwen2VLProcessor()
        let (rendered, chunks) = try validate(processor: processor, chatTemplate: template)
        #expect(rendered.contains("<|vision_start|>") && rendered.contains("<|vision_end|>"))
        #expect(chunks == [.text("<|im_start|>system \(systemMarker)<|im_end|> <|im_start|>user <|vision_start|>"), .image([.testImage]), .text("<|vision_end|>\(userMarker)<|im_end|> <|im_start|>assistant \(assistantMarker)<|im_end|> <|im_start|>assistant ")])
    }

    @Test
    func qwen3() async throws {
        // https://huggingface.co/unsloth/Qwen3-8B-GGUF
        let template = ##"{%- if tools %} {{- '<|im_start|>system\n' }} {%- if messages[0].role == 'system' %} {{- messages[0].content + '\n\n' }} {%- endif %} {{- "# Tools\n\nYou may call one or more functions to assist with the user query.\n\nYou are provided with function signatures within <tools></tools> XML tags:\n<tools>" }} {%- for tool in tools %} {{- "\n" }} {{- tool | tojson }} {%- endfor %} {{- "\n</tools>\n\nFor each function call, return a json object with function name and arguments within <tool_call></tool_call> XML tags:\n<tool_call>\n{\"name\": <function-name>, \"arguments\": <args-json-object>}\n</tool_call><|im_end|>\n" }} {%- else %} {%- if messages[0].role == 'system' %} {{- '<|im_start|>system\n' + messages[0].content + '<|im_end|>\n' }} {%- endif %} {%- endif %} {%- set ns = namespace(multi_step_tool=true, last_query_index=messages|length - 1) %} {%- for forward_message in messages %} {%- set index = (messages|length - 1) - loop.index0 %} {%- set message = messages[index] %} {%- set current_content = message.content if message.content is not none else '' %} {%- set tool_start = '<tool_response>' %} {%- set tool_start_length = tool_start|length %} {%- set start_of_message = current_content[:tool_start_length] %} {%- set tool_end = '</tool_response>' %} {%- set tool_end_length = tool_end|length %} {%- set start_pos = (current_content|length) - tool_end_length %} {%- if start_pos < 0 %} {%- set start_pos = 0 %} {%- endif %} {%- set end_of_message = current_content[start_pos:] %} {%- if ns.multi_step_tool and message.role == "user" and not(start_of_message == tool_start and end_of_message == tool_end) %} {%- set ns.multi_step_tool = false %} {%- set ns.last_query_index = index %} {%- endif %} {%- endfor %} {%- for message in messages %} {%- if (message.role == "user") or (message.role == "system" and not loop.first) %} {{- '<|im_start|>' + message.role + '\n' + message.content + '<|im_end|>' + '\n' }} {%- elif message.role == "assistant" %} {%- set content = message.content %} {%- set reasoning_content = '' %} {%- if message.reasoning_content is defined and message.reasoning_content is not none %} {%- set reasoning_content = message.reasoning_content %} {%- else %} {%- if '</think>' in message.content %} {%- set content = (message.content.split('</think>')|last).lstrip('\n') %} {%- set reasoning_content = (message.content.split('</think>')|first).rstrip('\n') %} {%- set reasoning_content = (reasoning_content.split('<think>')|last).lstrip('\n') %} {%- endif %} {%- endif %} {%- if loop.index0 > ns.last_query_index %} {%- if loop.last or (not loop.last and reasoning_content) %} {{- '<|im_start|>' + message.role + '\n<think>\n' + reasoning_content.strip('\n') + '\n</think>\n\n' + content.lstrip('\n') }} {%- else %} {{- '<|im_start|>' + message.role + '\n' + content }} {%- endif %} {%- else %} {{- '<|im_start|>' + message.role + '\n' + content }} {%- endif %} {%- if message.tool_calls %} {%- for tool_call in message.tool_calls %} {%- if (loop.first and content) or (not loop.first) %} {{- '\n' }} {%- endif %} {%- if tool_call.function %} {%- set tool_call = tool_call.function %} {%- endif %} {{- '<tool_call>\n{"name": "' }} {{- tool_call.name }} {{- '", "arguments": ' }} {%- if tool_call.arguments is string %} {{- tool_call.arguments }} {%- else %} {{- tool_call.arguments | tojson }} {%- endif %} {{- '}\n</tool_call>' }} {%- endfor %} {%- endif %} {{- '<|im_end|>\n' }} {%- elif message.role == "tool" %} {%- if loop.first or (messages[loop.index0 - 1].role != "tool") %} {{- '<|im_start|>user' }} {%- endif %} {{- '\n<tool_response>\n' }} {{- message.content }} {{- '\n</tool_response>' }} {%- if loop.last or (messages[loop.index0 + 1].role != "tool") %} {{- '<|im_end|>\n' }} {%- endif %} {%- endif %} {%- endfor %} {%- if add_generation_prompt %} {{- '<|im_start|>assistant\n' }} {%- if enable_thinking is defined and enable_thinking is false %} {{- '<think>\n\n</think>\n\n' }} {%- endif %} {%- endif %}"##
        let processor = MessageProcessorFactory.chatMLProcessor()
        let (rendered, chunks) = try validate(processor: processor, chatTemplate: template)
        #expect(rendered.contains("<|im_start|>") && rendered.contains("<|im_end|>"))
        #expect(chunks == [.text("<|im_start|>system\n\(systemMarker)<|im_end|>\n<|im_start|>user\n\(userMarker)<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n\(assistantMarker)<|im_end|>\n<|im_start|>assistant\n")])
    }

    @Test
    func gemma_3() async throws {
        // https://huggingface.co/google/gemma-3-4b-it-qat-q4_0-gguf
        let template = #"{{ bos_token }} {%- if messages[0]['role'] == 'system' -%} {%- if messages[0]['content'] is string -%} {%- set first_user_prefix = messages[0]['content'] + ' ' -%} {%- else -%} {%- set first_user_prefix = messages[0]['content'][0]['text'] + ' ' -%} {%- endif -%} {%- set loop_messages = messages[1:] -%} {%- else -%} {%- set first_user_prefix = "" -%} {%- set loop_messages = messages -%} {%- endif -%} {%- for message in loop_messages -%} {%- if (message['role'] == 'user') != (loop.index0 % 2 == 0) -%} {{ raise_exception("Conversation roles must alternate user/assistant/user/assistant/...") }} {%- endif -%} {%- if (message['role'] == 'assistant') -%} {%- set role = "model" -%} {%- else -%} {%- set role = message['role'] -%} {%- endif -%} {{ '<start_of_turn>' + role + ' ' + (first_user_prefix if loop.first else "") }} {%- if message['content'] is string -%} {{ message['content'] | trim }} {%- elif message['content'] is iterable -%} {%- for item in message['content'] -%} {%- if item['type'] == 'image' -%} {{ '<start_of_image>' }} {%- elif item['type'] == 'text' -%} {{ item['text'] | trim }} {%- endif -%} {%- endfor -%} {%- else -%} {{ raise_exception("Invalid content type") }} {%- endif -%} {{ '<end_of_turn> ' }} {%- endfor -%} {%- if add_generation_prompt -%} {{'<start_of_turn>model '}} {%- endif -%}"#
        let processor = MessageProcessorFactory.gemma3Processor()
        let (rendered, chunks) = try validate(processor: processor, chatTemplate: template)
        #expect(rendered.contains("<start_of_turn>") && rendered.contains("<end_of_turn>"))
        #expect(chunks == [.text("<start_of_turn>user \(systemMarker) "), .image([.testImage]), .text("\(userMarker)<end_of_turn> <start_of_turn>model \(assistantMarker)<end_of_turn> <start_of_turn>model ")])
    }

    @Test
    func llama3_2_V() async throws {
        // https://huggingface.co/leafspark/Llama-3.2-11B-Vision-Instruct-GGUF
        let template = #"{{- bos_token }} {%- if custom_tools is defined %} {%- set tools = custom_tools %} {%- endif %} {%- if not tools_in_user_message is defined %} {%- set tools_in_user_message = true %} {%- endif %} {%- if not date_string is defined %} {%- if strftime_now is defined %} {%- set date_string = strftime_now("%d %b %Y") %} {%- else %} {%- set date_string = "26 Jul 2024" %} {%- endif %} {%- endif %} {%- if not tools is defined %} {%- set tools = none %} {%- endif %} {#- This block extracts the system message, so we can slot it into the right place. #} {%- if messages[0]['role'] == 'system' %} {%- set system_message = messages[0]['content']|trim %} {%- set messages = messages[1:] %} {%- else %} {%- set system_message = "" %} {%- endif %} {#- Find out if there are any images #} {% set image_ns = namespace(has_images=false) %} {%- for message in messages %} {%- for content in message['content'] %} {%- if content['type'] == 'image' %} {%- set image_ns.has_images = true %} {%- endif %} {%- endfor %} {%- endfor %} {#- Error out if there are images and system message #} {%- if image_ns.has_images and not system_message == "" %} {{- raise_exception("Prompting with images is incompatible with system messages.") }} {%- endif %} {#- System message if there are no images #} {%- if not image_ns.has_images %} {{- "<|start_header_id|>system<|end_header_id|>\n\n" }} {%- if tools is not none %} {{- "Environment: ipython\n" }} {%- endif %} {{- "Cutting Knowledge Date: December 2023\n" }} {{- "Today Date: " + date_string + "\n\n" }} {%- if tools is not none and not tools_in_user_message %} {{- "You have access to the following functions. To call a function, please respond with JSON for a function call." }} {{- 'Respond in the format {"name": function name, "parameters": dictionary of argument name and its value}.' }} {{- "Do not use variables.\n\n" }} {%- for t in tools %} {{- t | tojson(indent=4) }} {{- "\n\n" }} {%- endfor %} {%- endif %} {{- system_message }} {{- "<|eot_id|>" }} {%- endif %} {#- Custom tools are passed in a user message with some extra guidance #} {%- if tools_in_user_message and not tools is none %} {#- Extract the first user message so we can plug it in here #} {%- if messages | length != 0 %} {%- set first_user_message = messages[0]['content']|trim %} {%- set messages = messages[1:] %} {%- else %} {{- raise_exception("Cannot put tools in the first user message when there's no first user message!") }} {%- endif %} {{- '<|start_header_id|>user<|end_header_id|>\n\n' -}} {{- "Given the following functions, please respond with a JSON for a function call " }} {{- "with its proper arguments that best answers the given prompt.\n\n" }} {{- 'Respond in the format {"name": function name, "parameters": dictionary of argument name and its value}.' }} {{- "Do not use variables.\n\n" }} {%- for t in tools %} {{- t | tojson(indent=4) }} {{- "\n\n" }} {%- endfor %} {{- first_user_message + "<|eot_id|>"}} {%- endif %} {%- for message in messages %} {%- if not (message.role == 'ipython' or message.role == 'tool' or 'tool_calls' in message) %} {{- '<|start_header_id|>' + message['role'] + '<|end_header_id|>\n\n' }} {%- if message['content'] is string %} {{- message['content'] }} {%- else %} {%- for content in message['content'] %} {%- if content['type'] == 'image' %} {{- '<|image|>' }} {%- elif content['type'] == 'text' %} {{- content['text'] }} {%- endif %} {%- endfor %} {%- endif %} {{- '<|eot_id|>' }} {%- elif 'tool_calls' in message %} {%- if not message.tool_calls|length == 1 %} {{- raise_exception("This model only supports single tool-calls at once!") }} {%- endif %} {%- set tool_call = message.tool_calls[0].function %} {{- '<|start_header_id|>assistant<|end_header_id|>\n\n' -}} {{- '{"name": "' + tool_call.name + '", ' }} {{- '"parameters": ' }} {{- tool_call.arguments | tojson }} {{- "}" }} {{- "<|eot_id|>" }} {%- elif message.role == "tool" or message.role == "ipython" %} {{- "<|start_header_id|>ipython<|end_header_id|>\n\n" }} {%- if message.content is mapping or message.content is iterable %} {{- message.content | tojson }} {%- else %} {{- message.content }} {%- endif %} {{- "<|eot_id|>" }} {%- endif %} {%- endfor %} {%- if add_generation_prompt %} {{- '<|start_header_id|>assistant<|end_header_id|>\n\n' }} {%- endif %}"#
        // "Prompting with images is incompatible with system messages.", so system messages are not used.
        let processor = MessageProcessorFactory.llama32VisionProcessor()
        let (rendered, chunks) = try validate(processor: processor, chatTemplate: template, messages: [
            .user(userMarker, attachments: [.testImage]),
            .assistant(assistantMarker),
        ])
        #expect(rendered.contains("<|start_header_id|>") && rendered.contains("<|end_header_id|>"))
        #expect(chunks == [.text("  <|start_header_id|>user<|end_header_id|>\n\n\(userMarker)"), .image([.testImage]), .text("<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n\(assistantMarker)<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n")])
    }

    @Test
    func llama4() async throws {
        // https://huggingface.co/unsloth/Llama-4-Scout-17B-16E-Instruct-GGUF
        let template = #"{{- bos_token }} {%- if custom_tools is defined %} {%- set tools = custom_tools %} {%- endif %} {%- if not tools_in_user_message is defined %} {%- set tools_in_user_message = true %} {%- endif %} {%- if not date_string is defined %} {%- if strftime_now is defined %} {%- set date_string = strftime_now("%d %b %Y") %} {%- else %} {%- set date_string = "26 Jul 2024" %} {%- endif %} {%- endif %} {%- if not tools is defined %} {%- set tools = none %} {%- endif %} {#- This block extracts the system message, so we can slot it into the right place. #} {%- if messages[0]['role'] == 'system' %} {%- if messages[0]['content'] is string %} {%- set system_message = messages[0]['content']|trim %} {%- else %} {#- FIXME: The processor requires an array, always. #} {%- set system_message = messages[0]['content'][0]['text']|trim %} {%- endif %} {%- set messages = messages[1:] %} {%- set user_supplied_system_message = true %} {%- else %} {%- set system_message = "" %} {%- set user_supplied_system_message = false %} {%- endif %} {#- System message if the user supplied one #} {%- if user_supplied_system_message %} {{- "<|header_start|>system<|header_end|>\n\n" }} {%- if tools is not none %} {{- "Environment: ipython\n" }} {%- endif %} {%- if tools is not none and not tools_in_user_message %} {{- "You have access to the following functions. To call a function, please respond with JSON for a function call." }} {{- 'Respond in the format {"name": function name, "parameters": dictionary of argument name and its value}.' }} {{- "Do not use variables.\n\n" }} {%- for t in tools %} {{- t | tojson(indent=4) }} {{- "\n\n" }} {%- endfor %} {%- endif %} {{- system_message }} {{- "<|eot|>" }} {%- endif %} {#- Custom tools are passed in a user message with some extra guidance #} {%- if tools_in_user_message and not tools is none %} {#- Extract the first user message so we can plug it in here #} {%- if messages | length != 0 %} {%- set first_user_message = messages[0]['content']|trim %} {%- set messages = messages[1:] %} {%- else %} {{- raise_exception("Cannot put tools in the first user message when there's no first user message!") }} {%- endif %} {{- '<|header_start|>user<|header_end|>\n\n' -}} {{- "Given the following functions, please respond with a JSON for a function call " }} {{- "with its proper arguments that best answers the given prompt.\n\n" }} {{- 'Respond in the format {"name": function name, "parameters": dictionary of argument name and its value}.' }} {{- "Do not use variables.\n\n" }} {%- for t in tools %} {{- t | tojson(indent=4) }} {{- "\n\n" }} {%- endfor %} {{- first_user_message + "<|eot|>"}} {%- endif %} {%- for message in messages %} {%- if not (message.role == 'ipython' or message.role == 'tool' or 'tool_calls' in message) %} {{- '<|header_start|>' + message['role'] + '<|header_end|>\n\n' }} {%- if message['content'] is string %} {{- message['content'] }} {%- else %} {%- for content in message['content'] %} {%- if content['type'] == 'image' %} {{- '<|image|>' }} {%- elif content['type'] == 'text' %} {{- content['text'] }} {%- endif %} {%- endfor %} {%- endif %} {{- "<|eot|>" }} {%- elif 'tool_calls' in message and message.tool_calls|length > 0 %} {{- '<|header_start|>assistant<|header_end|>\n\n' -}} {{- '<|python_start|>' }} {%- if message['content'] is string %} {{- message['content'] }} {%- else %} {%- for content in message['content'] %} {%- if content['type'] == 'image' %} {{- '<|image|>' }} {%- elif content['type'] == 'text' %} {{- content['text'] }} {%- endif %} {%- endfor %} {%- endif %} {{- '<|python_end|>' }} {%- for tool_call in message.tool_calls %} {{- '{"name": "' + tool_call.function.name + '", ' }} {{- '"parameters": ' }} {{- tool_call.function.arguments | tojson }} {{- "}" }} {%- endfor %} {{- "<|eot|>" }} {%- elif message.role == "tool" or message.role == "ipython" %} {{- "<|header_start|>ipython<|header_end|>\n\n" }} {%- if message.content is mapping or message.content is iterable %} {{- message.content | tojson }} {%- else %} {{- message.content }} {%- endif %} {{- "<|eot|>" }} {%- endif %} {%- endfor %} {%- if add_generation_prompt %} {{- '<|header_start|>assistant<|header_end|>\n\n' }} {%- endif %}"#
        let processor = MessageProcessorFactory.llama32VisionProcessor()
        let (rendered, chunks) = try validate(processor: processor, chatTemplate: template)
        #expect(rendered.contains("<|header_start|>") && rendered.contains("<|header_end|>"))
        #expect(chunks == [.text("<|header_start|>system<|header_end|>\n\n\(systemMarker)<|eot|><|header_start|>user<|header_end|>\n\n\(userMarker)"), .image([.testImage]), .text("<|eot|><|header_start|>assistant<|header_end|>\n\n\(assistantMarker)<|eot|><|header_start|>assistant<|header_end|>\n\n")])
    }

    @Test
    func phi4() async throws {
        // https://huggingface.co/microsoft/phi-4-gguf
        let template = #"{% for message in messages %}{% if (message['role'] == 'system') %}{{'<|im_start|>system<|im_sep|>' + message['content'] + '<|im_end|>'}}{% elif (message['role'] == 'user') %}{{'<|im_start|>user<|im_sep|>' + message['content'] + '<|im_end|>'}}{% elif (message['role'] == 'assistant') %}{{'<|im_start|>assistant<|im_sep|>' + message['content'] + '<|im_end|>'}}{% endif %}{% endfor %}{% if add_generation_prompt %}{{ '<|im_start|>assistant<|im_sep|>' }}{% endif %}"#
        let processor = MessageProcessorFactory.chatMLProcessor()
        let (rendered, chunks) = try validate(processor: processor, chatTemplate: template)
        #expect(rendered.contains("<|im_start|>") && rendered.contains("<|im_end|>"))
        #expect(chunks == [.text("<|im_start|>system<|im_sep|>\(systemMarker)<|im_end|><|im_start|>user<|im_sep|>\(userMarker)<|im_end|><|im_start|>assistant<|im_sep|>\(assistantMarker)<|im_end|><|im_start|>assistant<|im_sep|>")])
    }

    @Test
    func deepseek3() async throws {
        // https://huggingface.co/unsloth/DeepSeek-V3-0324-GGUF
        let template = #"{% if not add_generation_prompt is defined %}{% set add_generation_prompt = false %}{% endif %}{% set ns = namespace(is_first=false, is_tool=false, is_output_first=true, system_prompt='', is_first_sp=true, is_last_user=false) %}{%- for message in messages %}{%- if message['role'] == 'system' %}{%- if ns.is_first_sp %}{% set ns.system_prompt = ns.system_prompt + message['content'] %}{% set ns.is_first_sp = false %}{%- else %}{% set ns.system_prompt = ns.system_prompt + ' ' + message['content'] %}{%- endif %}{%- endif %}{%- endfor %}{{ bos_token }}{{ ns.system_prompt }}{%- for message in messages %}{%- if message['role'] == 'user' %}{%- set ns.is_tool = false -%}{%- set ns.is_first = false -%}{%- set ns.is_last_user = true -%}{{'<｜User｜>' + message['content'] + '<｜Assistant｜>'}}{%- endif %}{%- if message['role'] == 'assistant' and message['tool_calls'] is defined and message['tool_calls'] is not none %}{%- set ns.is_last_user = false -%}{%- if ns.is_tool %}{{'<｜tool▁outputs▁end｜>'}}{%- endif %}{%- set ns.is_first = false %}{%- set ns.is_tool = false -%}{%- set ns.is_output_first = true %}{%- for tool in message['tool_calls'] %}{%- if not ns.is_first %}{%- if message['content'] is none %}{{'<｜tool▁calls▁begin｜><｜tool▁call▁begin｜>' + tool['type'] + '<｜tool▁sep｜>' + tool['function']['name'] + ' ' + '```json' + ' ' + tool['function']['arguments'] + ' ' + '```' + '<｜tool▁call▁end｜>'}}{%- else %}{{message['content'] + '<｜tool▁calls▁begin｜><｜tool▁call▁begin｜>' + tool['type'] + '<｜tool▁sep｜>' + tool['function']['name'] + ' ' + '```json' + ' ' + tool['function']['arguments'] + ' ' + '```' + '<｜tool▁call▁end｜>'}}{%- endif %}{%- set ns.is_first = true -%}{%- else %}{{' ' + '<｜tool▁call▁begin｜>' + tool['type'] + '<｜tool▁sep｜>' + tool['function']['name'] + ' ' + '```json' + ' ' + tool['function']['arguments'] + ' ' + '```' + '<｜tool▁call▁end｜>'}}{%- endif %}{%- endfor %}{{'<｜tool▁calls▁end｜><｜end▁of▁sentence｜>'}}{%- endif %}{%- if message['role'] == 'assistant' and (message['tool_calls'] is not defined or message['tool_calls'] is none)%}{%- set ns.is_last_user = false -%}{%- if ns.is_tool %}{{'<｜tool▁outputs▁end｜>' + message['content'] + '<｜end▁of▁sentence｜>'}}{%- set ns.is_tool = false -%}{%- else %}{% set content = message['content'] %}{{content + '<｜end▁of▁sentence｜>'}}{%- endif %}{%- endif %}{%- if message['role'] == 'tool' %}{%- set ns.is_last_user = false -%}{%- set ns.is_tool = true -%}{%- if ns.is_output_first %}{{'<｜tool▁outputs▁begin｜><｜tool▁output▁begin｜>' + message['content'] + '<｜tool▁output▁end｜>'}}{%- set ns.is_output_first = false %}{%- else %}{{' <｜tool▁output▁begin｜>' + message['content'] + '<｜tool▁output▁end｜>'}}{%- endif %}{%- endif %}{%- endfor -%}{% if ns.is_tool %}{{'<｜tool▁outputs▁end｜>'}}{% endif %}{% if add_generation_prompt and not ns.is_last_user and not ns.is_tool %}{{'<｜Assistant｜>'}}{% endif %}"#
        let processor = MessageProcessorFactory.chatMLProcessor()
        let (rendered, chunks) = try validate(processor: processor, chatTemplate: template)
        #expect(rendered.contains("<｜User｜>") && rendered.contains("<｜Assistant｜>"))
        #expect(chunks == [.text("\(systemMarker)<｜User｜>\(userMarker)<｜Assistant｜>\(assistantMarker)<｜end▁of▁sentence｜><｜Assistant｜>")])
    }

    @Test
    func mistral_v7() async throws {
        // https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF
        let template = #"{{ bos_token }}{% for message in messages %}{% if (message['role'] == 'user') != (loop.index0 % 2 == 0) %}{{ raise_exception('Conversation roles must alternate user/assistant/user/assistant/...') }}{% endif %}{% if message['role'] == 'user' %}{{ '[INST] ' + message['content'] + ' [/INST]' }}{% elif message['role'] == 'assistant' %}{{ message['content'] + eos_token}}{% else %}{{ raise_exception('Only user and assistant roles are supported!') }}{% endif %}{% endfor %}"#
        let processor = MessageProcessorFactory.chatMLProcessor()
        let (rendered, chunks) = try validate(processor: processor, chatTemplate: template, messages: [
            .user(userMarker, attachments: [.testImage]),
            .assistant(assistantMarker),
        ])
        #expect(rendered.contains("[INST]") && rendered.contains("[/INST]"))
        #expect(chunks == [.text("[INST] \(userMarker) [/INST]\(assistantMarker)eos_token")])
    }

    @Test
    func autoDetection() async throws {
        // Test that auto-detection works correctly for different templates
        let templates = [
            ("qwen2_5_VL", #"{% set image_count = namespace(value=0) %}{% set video_count = namespace(value=0) %}{% for message in messages %}{% if loop.first and message['role'] != 'system' %}<|im_start|>system You are a helpful assistant.<|im_end|> {% endif %}<|im_start|>{{ message['role'] }} {% if message['content'] is string %}{{ message['content'] }}<|im_end|> {% else %}{% for content in message['content'] %}{% if content['type'] == 'image' or 'image' in content or 'image_url' in content %}{% set image_count.value = image_count.value + 1 %}{% if add_vision_id %}Picture {{ image_count.value }}: {% endif %}<|vision_start|><|image_pad|><|vision_end|>{% elif content['type'] == 'video' or 'video' in content %}{% set video_count.value = video_count.value + 1 %}{% if add_vision_id %}Video {{ video_count.value }}: {% endif %}<|vision_start|><|video_pad|><|vision_end|>{% elif 'text' in content %}{{ content['text'] }}{% endif %}{% endfor %}<|im_end|> {% endif %}{% endfor %}{% if add_generation_prompt %}<|im_start|>assistant {% endif %}"#),
            ("gemma3", #"{{ bos_token }} {%- if messages[0]['role'] == 'system' -%} {%- if messages[0]['content'] is string -%} {%- set first_user_prefix = messages[0]['content'] + ' ' -%} {%- else -%} {%- set first_user_prefix = messages[0]['content'][0]['text'] + ' ' -%} {%- endif -%} {%- set loop_messages = messages[1:] -%} {%- else -%} {%- set first_user_prefix = "" -%} {%- set loop_messages = messages -%} {%- endif -%} {%- for message in loop_messages -%} {%- if (message['role'] == 'user') != (loop.index0 % 2 == 0) -%} {{ raise_exception("Conversation roles must alternate user/assistant/user/assistant/...") }} {%- endif -%} {%- if (message['role'] == 'assistant') -%} {%- set role = "model" -%} {%- else -%} {%- set role = message['role'] -%} {%- endif -%} {{ '<start_of_turn>' + role + ' ' + (first_user_prefix if loop.first else "") }} {%- if message['content'] is string -%} {{ message['content'] | trim }} {%- elif message['content'] is iterable -%} {%- for item in message['content'] -%} {%- if item['type'] == 'image' -%} {{ '<start_of_image>' }} {%- elif item['type'] == 'text' -%} {{ item['text'] | trim }} {%- endif -%} {%- endfor -%} {%- else -%} {{ raise_exception("Invalid content type") }} {%- endif -%} {{ '<end_of_turn> ' }} {%- endfor -%} {%- if add_generation_prompt -%} {{'<start_of_turn>model '}} {%- endif -%}"#),
        ]
        
        for (name, template) in templates {
            let autoProcessor = MessageProcessorFactory.createAutoProcessor(chatTemplate: template)
            let (rendered, _) = try validate(processor: autoProcessor, chatTemplate: template)
            #expect(rendered.count > 0, "Auto-detection failed for \(name)")
        }
    }
    
    func validate(processor: MessageProcessor, chatTemplate: String, messages: [LLMInput.Message]? = nil) throws -> (rendered: String, chunks: [MessageChunk]) {
        let specialTokens: [String: String] = [
//            "bos_token": "bos_token",
            "eos_token": "eos_token",
            "unk_token": "unk_token",
            "sep_token": "sep_token",
            "pad_token": "pad_token",
            "cls_token": "cls_token",
            "mask_token": "mask_token",
            "additional_special_tokens": "additional_special_tokens",
        ]

        let messages: [LLMInput.Message] = messages ?? [
            .system(systemMarker),
            .user(userMarker, attachments: [.testImage]),
            .assistant(assistantMarker),
        ]
        
        return try processor.renderAndExtractChunks(
            messages: messages,
            template: chatTemplate,
            specialTokens: specialTokens
        )
    }
}

private extension LLMInputImage {
    nonisolated(unsafe) static let testImage = LLMInputImage()
}

private extension LLMAttachment {
    static let testImage = LLMAttachment.image(.testImage)
}
