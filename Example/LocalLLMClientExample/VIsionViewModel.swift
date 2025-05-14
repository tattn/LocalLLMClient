import Foundation
import LocalLLMClient

@Observable @MainActor
final class VisionViewModel {
    var inputText = ""
    var image: LLMInputImage?
    private(set) var outputText = ""
    private var generateTask: Task<Void, Never>?

    var isGenerating: Bool {
        generateTask != nil
    }

    func sendMessage(to ai: AI) {
        guard !inputText.isEmpty, let image, !isGenerating else { return }
        guard ai.model.supportsVision else {
            outputText = "The current model does not support vision."
            return
        }

        let messages: [LLMInput.Message] = [
            .user(inputText, attachments: [.image(image)])
        ]

        generateTask = Task {
            do {
                outputText = ""
                for try await token in try await ai.ask(messages) {
                    outputText += token
                }
            } catch {
                outputText = "Error: \(error.localizedDescription)"
            }

            generateTask = nil
        }
    }

    func cancelGeneration() {
        generateTask?.cancel()
        generateTask = nil
    }
}
