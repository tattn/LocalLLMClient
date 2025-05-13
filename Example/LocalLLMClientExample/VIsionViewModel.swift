import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import LocalLLMClient

@Observable @MainActor
final class VisionViewModel {
    var inputText = ""
    var outputText = ""
    var image: LLMInputImage?
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

        let size = CGSize(width: 448, height: 448)
#if os(macOS)
        let resizedImage = LLMInputImage(size: size)
        resizedImage.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: size))
        resizedImage.unlockFocus()
#elseif os(iOS)
        let resizedImage = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
#endif

        let messages: [LLMInput.Message] = [
            .user(inputText, attachments: [.image(resizedImage)])
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
