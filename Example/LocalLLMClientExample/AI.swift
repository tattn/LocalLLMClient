import Foundation
import LocalLLMClient
import LocalLLMClientMLX
import LocalLLMClientLlama
#if canImport(UIKit)
import UIKit
#endif

enum LLMModel: Sendable, CaseIterable, Identifiable {
    case qwen3
    case qwen3_4b
    case qwen2_5VL_3b
    case gemma3
    case gemma3_4b
    case mobileVLM_3b

    var name: String {
        switch self {
        case .qwen3: "MLX / Qwen3 1.7B"
        case .qwen3_4b: "MLX / Qwen3 4B"
        case .qwen2_5VL_3b: "MLX / Qwen2.5VL 3B"
        case .gemma3: "llama.cpp / Gemma3 1B"
        case .gemma3_4b: "llama.cpp / Gemma3 4B"
        case .mobileVLM_3b: "llama.cpp / MobileVLM 3B"
        }
    }

    var id: String {
        switch self {
        case .qwen3: "mlx-community/Qwen3-1.7B-4bit"
        case .qwen3_4b: "mlx-community/Qwen3-4B-4bit"
        case .qwen2_5VL_3b: "mlx-community/Qwen2.5-VL-3B-Instruct-abliterated-4bit"
        case .gemma3: "lmstudio-community/gemma-3-1B-it-qat-GGUF"
        case .gemma3_4b: "lmstudio-community/gemma-3-4B-it-qat-GGUF"
        case .mobileVLM_3b: "Blombert/MobileVLM-3B-GGUF"
        }
    }

    var filename: String? {
        switch self {
        case .qwen3, .qwen3_4b, .qwen2_5VL_3b: nil
        case .gemma3: "gemma-3-1B-it-QAT-Q4_0.gguf"
        case .gemma3_4b: "gemma-3-4B-it-QAT-Q4_0.gguf"
        case .mobileVLM_3b: "ggml-MobileVLM-3B-q5_k_s.gguf"
        }
    }

    var clipFilename: String? {
        switch self {
        case .qwen3, .qwen3_4b, .qwen2_5VL_3b, .gemma3: nil
#if os(macOS)
        case .gemma3_4b: "mmproj-model-f16.gguf"
#elseif os(iOS)
        case .gemma3_4b: nil
#endif
        case .mobileVLM_3b: "mmproj-model-f16.gguf"
        }
    }

    var isMLX: Bool {
        switch self {
        case .qwen3, .qwen3_4b, .qwen2_5VL_3b: true
        case .gemma3, .gemma3_4b, .mobileVLM_3b: false
        }
    }

    var supportsVision: Bool {
        switch self {
        case .qwen3, .qwen3_4b, .gemma3: false
#if os(macOS)
        case .gemma3_4b: true
#elseif os(iOS)
        case .gemma3_4b: false
#endif
        case .qwen2_5VL_3b, .mobileVLM_3b: true
        }
    }
}

@Observable @MainActor
final class AI {
    var model = LLMModel.qwen3
    private(set) var isLoading = false
    private(set) var downloadProgress: Double = 0

    private var client: AnyLLMClient?

    func loadLLM() async {
        isLoading = true
        defer { isLoading = false }

        // Release memory first if a previous model was loaded
        client = nil

        do {
            let downloader = Downloader(model: model)
            if downloader.isDownloaded {
                downloadProgress = 1
            } else {
                downloadProgress = 0
                try await downloader.download { @MainActor [weak self] progress in
                    self?.downloadProgress = progress
                }
            }

            #if os(iOS)
            while downloadProgress < 1 || UIApplication.shared.applicationState != .active {
                try await Task.sleep(for: .seconds(2))
            }
            #endif

            if model.isMLX {
                client = try await AnyLLMClient(LocalLLMClient.mlx(url: downloader.url))
            } else {
                client = try await AnyLLMClient(LocalLLMClient.llama(url: downloader.url, mmprojURL: downloader.clipURL, verbose: true))
            }
        } catch {
            print("Failed to load LLM: \(error)")
        }
    }

    func ask(_ messages: [LLMInput.Message]) async throws -> AsyncThrowingStream<String, any Error> {
        guard let client else {
            throw LLMError.failedToLoad(reason: "LLM not loaded")
        }
        return try await client.textStream(from: .chat(messages))
    }
}
