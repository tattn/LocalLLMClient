import LocalLLMClientCore
import Foundation

/// Protocol for transforming user-facing messages to template-ready messages
protocol MessageTransformer: Sendable {
    /// Transform messages into chat template format
    func transform(_ messages: [LLMInput.Message]) -> [LLMInput.ChatTemplateMessage]
}

/// Standard transformer that handles text and multimodal content
struct StandardMessageTransformer: MessageTransformer {
    init() {}

    func transform(_ messages: [LLMInput.Message]) -> [LLMInput.ChatTemplateMessage] {
        messages.map { message in
            var value: [String: any Sendable] = [
                "role": message.role.rawValue,
                "content": buildContent(for: message)
            ]

            // Preserve tool metadata
            if message.role == .tool, let toolCallID = message.metadata["tool_call_id"] {
                value["tool_call_id"] = toolCallID
            }

            return LLMInput.ChatTemplateMessage(
                value: value,
                attachments: message.attachments
            )
        }
    }

    private func buildContent(for message: LLMInput.Message) -> any Sendable {
        let imageCount = message.attachments.filter { attachment in
            if case .image = attachment.content { return true }
            return false
        }.count

        if imageCount > 0 {
            return (0..<imageCount).map { _ in
                ["type": "image"] as [String: String]
            } + [["type": "text", "text": message.content] as [String: String]]
        } else {
            // Always return array format for consistency with templates
            return [["type": "text", "text": message.content] as [String: String]]
        }
    }
}

/// Transformer for models that require different handling of multimodal content in user messages
struct RoleBasedMessageTransformer: MessageTransformer {
    init() {}

    func transform(_ messages: [LLMInput.Message]) -> [LLMInput.ChatTemplateMessage] {
        messages.map { message in
            switch message.role {
            case .system, .assistant, .custom, .tool:
                // Use array format for all roles for consistency
                var value: [String: any Sendable] = [
                    "role": message.role.rawValue,
                    "content": [["type": "text", "text": message.content] as [String: String]]
                ]

                if message.role == .tool, let toolCallID = message.metadata["tool_call_id"] {
                    value["tool_call_id"] = toolCallID
                }

                return LLMInput.ChatTemplateMessage(
                    value: value,
                    attachments: message.attachments
                )

            case .user:
                // Multimodal content for user role
                let imageCount = message.attachments.filter { attachment in
                    if case .image = attachment.content { return true }
                    return false
                }.count

                let content: any Sendable = if imageCount > 0 {
                    [["type": "text", "text": message.content]] + (0..<imageCount).map { _ in
                        ["type": "image"] as [String: String]
                    }
                } else {
                    message.content
                }

                return LLMInput.ChatTemplateMessage(
                    value: [
                        "role": message.role.rawValue,
                        "content": content
                    ],
                    attachments: message.attachments
                )
            }
        }
    }
}

/// Transformer for ChatML format (simple text-only messages)
struct ChatMLMessageTransformer: MessageTransformer {
    init() {}

    func transform(_ messages: [LLMInput.Message]) -> [LLMInput.ChatTemplateMessage] {
        messages.map { message in
            LLMInput.ChatTemplateMessage(
                value: ["role": message.role.rawValue, "content": message.content],
                attachments: message.attachments
            )
        }
    }
}
