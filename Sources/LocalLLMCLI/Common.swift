import Foundation

enum Backend: String, CaseIterable {
    case llama
    case mlx
    case foundationModels = "foundation-models"
}

enum LocalLLMCommandError: Error {
    case invalidModel(String)
}