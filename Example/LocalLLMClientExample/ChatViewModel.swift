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

    var messages: [LLMInput.Message] {
        var messages = ai.messages
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

            generateTask = nil
            generatingText = ""
        }
    }

    func cancelGeneration() {
        generateTask?.cancel()
        generateTask = nil
    }
}
