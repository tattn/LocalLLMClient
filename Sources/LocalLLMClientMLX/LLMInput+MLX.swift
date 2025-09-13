import Foundation
import LocalLLMClientCore
import MLXLMCommon

extension LLMInput {
    /// Converts LLMInput to MLX Chat.Message array
    var chatMessages: [Chat.Message] {
        switch value {
        case .plain(let text):
            [.user(text)]
        case .chatTemplate(let messages):
            messages.map {
                Chat.Message(
                    role: .init(rawValue: $0.value["role"] as? String ?? "") ?? .user,
                    content: $0.value["content"] as? String ?? "",
                    images: $0.attachments.images
                )
            }
        case .chat(let messages):
            messages.map {
                Chat.Message(
                    role: .init(rawValue: $0.role.rawValue) ?? .user,
                    content: $0.content,
                    images: $0.attachments.images
                )
            }
        }
    }
}

extension [LLMAttachment] {
    var images: [UserInput.Image] {
        compactMap {
            switch $0.content {
            case let .image(image):
                return try? UserInput.Image.ciImage(llmInputImageToCIImage(image))
            }
        }
    }
}