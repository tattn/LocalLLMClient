import Foundation
import LocalLLMClient

struct ChatMessage: Identifiable, Equatable, Sendable {
    var id = UUID()
    var role: Role
    var content: String

    enum Role: Sendable {
        case system
        case user
        case assistant
    }
}

@Observable @MainActor
final class ChatViewModel {
    var inputText = ""
    private(set) var messages: [ChatMessage] = []
    private var generateTask: Task<Void, Never>?

    var isGenerating: Bool {
        generateTask != nil
    }

    func sendMessage(to ai: AI) {
        guard !inputText.isEmpty, !isGenerating else { return }

        messages.append(ChatMessage(role: .user, content: inputText))
        let newMessages = messages
        messages.append(ChatMessage(role: .assistant, content: ""))

        let currentInput = inputText
        inputText = ""

        generateTask = Task {
            do {
                var response = ""
                for try await token in try await ai.ask(newMessages.llmMessages()) {
                    response += token
                    messages[messages.count - 1].content = response
                }
            } catch {
                messages[messages.count - 1].content = "Error: \(error.localizedDescription)"
                inputText = currentInput
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
            return LLMInput.Message(role: role, content: message.content)
        }
    }
}
