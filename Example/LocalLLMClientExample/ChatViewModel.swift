import Foundation
import LocalLLMClient

struct ChatMessage: Identifiable, Equatable, Sendable {
    var id = UUID()
    var role: Role
    var text: String
    var images: [Image] = []

    enum Role: Sendable {
        case system
        case user
        case assistant
    }

    struct Image: Identifiable, Equatable, @unchecked Sendable {
        var id = UUID()
        var value: LLMInputImage
    }
}

@Observable @MainActor
final class ChatViewModel {
    var inputText = ""
    var inputImages: [ChatMessage.Image] = []
    private(set) var messages: [ChatMessage] = []
    private var generateTask: Task<Void, Never>?

    init(messages: [ChatMessage] = []) {
        self.messages = messages
    }

    var isGenerating: Bool {
        generateTask != nil
    }

    func sendMessage(to ai: AI) {
        guard !inputText.isEmpty, !isGenerating else { return }

        messages.append(ChatMessage(role: .user, text: inputText, images: inputImages))
        let newMessages = messages
        messages.append(ChatMessage(role: .assistant, text: ""))

        let currentInput = (inputText, inputImages)
        inputText = ""
        inputImages = []

        generateTask = Task {
            do {
                var response = ""
                for try await token in try await ai.ask(newMessages.llmMessages()) {
                    response += token
                    messages[messages.count - 1].text = response
                }
            } catch {
                messages[messages.count - 1].text = "Error: \(error.localizedDescription)"
                (inputText, inputImages) = currentInput
            }

            generateTask = nil
        }
    }

    func cancelGeneration() {
        generateTask?.cancel()
        generateTask = nil
    }

    func clearMessages() {
        messages.removeAll()
    }
}

extension [ChatMessage] {
    func llmMessages() -> [LLMInput.Message] {
        map { message in
            var role: LLMInput.Message.Role {
                switch message.role {
                case .user: return .user
                case .assistant: return .assistant
                case .system: return .system
                }
            }
            let attachments: [LLMAttachment] = message.images.map { image in
                .image(image.value)
            }
            return LLMInput.Message(role: role, content: message.text, attachments: attachments)
        }
    }
}
