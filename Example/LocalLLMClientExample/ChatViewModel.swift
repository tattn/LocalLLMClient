import Foundation
import LocalLLMClient


@Observable @MainActor
final class ChatViewModel {
    init(ai: AI) {
        self.ai = ai
    }

    var inputText = ""
    var inputAttachments: [LLMAttachment] = []

    private var ai: AI
    private var generateTask: Task<Void, Never>?
    private var generatingText = ""
    /// Optimistically displayed user message until it lands in `ai.messages`.
    private var pendingUserMessage: LLMInput.Message?

    var messages: [LLMInput.Message] {
        var messages = ai.messages
        if let pendingUserMessage, messages.last?.role != .user {
            messages.append(pendingUserMessage)
        }
        if !generatingText.isEmpty, messages.last?.role != .assistant {
            messages.append(.assistant(generatingText))
        }
        return messages
    }

    var isGenerating: Bool {
        generateTask != nil
    }

    func sendMessage() {
        guard !inputText.isEmpty, !isGenerating else { return }

        let currentInput = (text: inputText, images: inputAttachments)
        inputText = ""
        inputAttachments = []
        pendingUserMessage = .user(currentInput.text, attachments: currentInput.images)

        generateTask = Task {
            generatingText = ""

            do {
                for try await token in try await ai.ask(currentInput.text, attachments: currentInput.images) {
                    generatingText += token
                }
            } catch {
                ai.messages.append(.assistant("Error: \(error.localizedDescription)"))
                (inputText, inputAttachments) = currentInput
            }

            pendingUserMessage = nil
            generateTask = nil
            generatingText = ""
        }
    }

    func cancelGeneration() {
        generateTask?.cancel()
        generateTask = nil
    }
}
