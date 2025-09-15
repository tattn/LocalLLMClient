import Foundation
#if canImport(LocalLLMClientUtility)
import LocalLLMClientUtility
#endif

enum Backend: String, CaseIterable {
    case llama
    case mlx
    case foundationModels = "foundation-models"
}

enum LocalLLMCommandError: Error {
    case invalidModel(String)
}

// MARK: - Model Loading Utilities

struct ModelLoader {
    let verbose: Bool
    
    init(verbose: Bool = false) {
        self.verbose = verbose
    }
    
    func getModel(for model: String, backend: Backend) async throws -> URL {
        if model.hasPrefix("/") {
            return URL(filePath: model)
        } else if model.hasPrefix("https://"), let url = URL(string: model) {
            return try await downloadModel(from: url, backend: backend)
        } else if model.isEmpty {
            throw LocalLLMCommandError.invalidModel("Error: Missing expected argument '--model <model>'")
        } else {
            throw LocalLLMCommandError.invalidModel(model)
        }
    }
    
    private func downloadModel(from url: URL, backend: Backend) async throws -> URL {
        #if canImport(LocalLLMClientUtility)
        log("Downloading model from Hugging Face: \(url)")
        
        let globs: Globs = switch backend {
        case .llama: .init(["*\(url.lastPathComponent)"])
        case .mlx: .mlx
        case .foundationModels: []
        }
        
        let downloader = FileDownloader(source: .huggingFace(
            id: url.pathComponents[1...2].joined(separator: "/"),
            globs: globs
        ))
        try await downloader.download { progress in
            log("Downloading model: \(progress)")
        }
        return switch backend {
        case .llama: downloader.destination.appendingPathComponent(url.lastPathComponent)
        case .mlx: downloader.destination
        case .foundationModels: throw LocalLLMCommandError.invalidModel("Model downloading is not applicable for the FoundationModels backend.")
        }
        #else
        throw LocalLLMCommandError.invalidModel("Downloading models is not supported on this platform.")
        #endif
    }
    
    private func log(_ message: String) {
        if verbose {
            print(message)
        }
    }
}