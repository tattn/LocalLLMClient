import Foundation
import LocalLLMClient
import LocalLLMClientMLX
import LocalLLMClientLlama
#if canImport(UIKit)
import UIKit
#endif

// TODO: Convert to struct
enum LLMModel: Sendable, CaseIterable, Identifiable {
    case qwen3
    case qwen3_4b
    case qwen2_5VL_3b
    case gemma3_4b_mlx
    case phi4mini
    case gemma3
    case gemma3_4b
    case mobileVLM_3b

    var name: String {
        switch self {
        case .qwen3: "MLX / Qwen3 1.7B"
        case .qwen3_4b: "MLX / Qwen3 4B"
        case .qwen2_5VL_3b: "MLX / Qwen2.5VL 3B"
        case .gemma3_4b_mlx: "MLX / Gemma3 4B"
        case .phi4mini: "llama.cpp / Phi-4 Mini 3.8B"
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
        case .gemma3_4b_mlx: "mlx-community/gemma-3-4b-it-qat-4bit"
        case .phi4mini: "unsloth/Phi-4-mini-instruct-GGUF"
        case .gemma3: "lmstudio-community/gemma-3-1B-it-qat-GGUF"
        case .gemma3_4b: "lmstudio-community/gemma-3-4B-it-qat-GGUF"
        case .mobileVLM_3b: "Blombert/MobileVLM-3B-GGUF"
        }
    }

    var filename: String? {
        switch self {
        case .qwen3, .qwen3_4b, .qwen2_5VL_3b, .gemma3_4b_mlx: nil
        case .phi4mini: "Phi-4-mini-instruct-Q4_K_M.gguf"
        case .gemma3: "gemma-3-1B-it-QAT-Q4_0.gguf"
        case .gemma3_4b: "gemma-3-4B-it-QAT-Q4_0.gguf"
        case .mobileVLM_3b: "ggml-MobileVLM-3B-q5_k_s.gguf"
        }
    }

    var mmprojFilename: String? {
        switch self {
        case .qwen3, .qwen3_4b, .qwen2_5VL_3b, .gemma3_4b_mlx, .phi4mini, .gemma3: nil
#if os(macOS)
        case .gemma3_4b: "mmproj-model-f16.gguf"
#elseif os(iOS)
        case .gemma3_4b: nil
#endif
        case .mobileVLM_3b: "mmproj-model-f16.gguf"
        }
    }

    var isMLX: Bool {
        filename == nil
    }

    var supportsVision: Bool {
        switch self {
        case .qwen3, .qwen3_4b, .phi4mini, .gemma3: false
#if os(macOS)
        case .gemma3_4b: true
#elseif os(iOS)
        case .gemma3_4b: false
#endif
        case .qwen2_5VL_3b, .gemma3_4b_mlx, .mobileVLM_3b: true
        }
    }

    var extraEOSTokens: Set<String> {
        switch self {
        case .gemma3_4b_mlx:
            return ["<end_of_turn>"]
        case .qwen3, .qwen3_4b, .qwen2_5VL_3b, .phi4mini, .gemma3, .gemma3_4b, .mobileVLM_3b:
            return []
        }
    }
    
    var supportsTools: Bool {
        switch self {
        case .qwen3, .qwen3_4b:
            return true
        case .qwen2_5VL_3b, .gemma3_4b_mlx, .phi4mini, .gemma3, .gemma3_4b, .mobileVLM_3b:
            return false
        }
    }
}

@Observable @MainActor
final class AI {
    var model = LLMModel.qwen3 {
        didSet {
            areToolsEnabled = model.supportsTools && areToolsEnabled
        }
    }
    private(set) var isLoading = false
    private(set) var downloadProgress: Double = 0
    var areToolsEnabled = false

    private var session: LLMSession?
    private let tools: [any LLMTool] = [
        WeatherTool(),
        CalculatorTool(),
        DateTimeTool(),
        RandomNumberTool()
    ]

    var messages: [LLMInput.Message] {
        get { session?.messages ?? [] }
        set { session?.messages = newValue }
    }
    
    func resetMessages() {
        messages = [.system("You are a helpful assistant who is responsible for helping the user with tasks using the provided tools.")]
    }

    func loadLLM() async {
        isLoading = true
        defer { isLoading = false }

        // Release memory first if a previous model was loaded
        session = nil

        do {
            let downloadModel: LLMSession.DownloadModel = if model.isMLX {
                .mlx(id: model.id, parameter: .init(options: .init(extraEOSTokens: model.extraEOSTokens)))
            } else {
                .llama(
                    id: model.id,
                    model: model.filename!,
                    mmproj: model.mmprojFilename,
                    parameter: .init(options: .init(extraEOSTokens: model.extraEOSTokens, verbose: true))
                )
            }

            try await downloadModel.downloadModel { @MainActor [weak self] progress in
                self?.downloadProgress = progress
                print("Download progress: \(progress)")
            }

            session = LLMSession(model: downloadModel, tools: areToolsEnabled ? tools : [])
            resetMessages()
        } catch {
            print("Failed to load LLM: \(error)")
        }
    }

    func ask(_ message: String, attachments: [LLMAttachment]) async throws -> AsyncThrowingStream<String, any Error> {
        guard let session else {
            throw LLMError.failedToLoad(reason: "LLM not loaded")
        }

        return session.streamResponse(to: message, attachments: attachments)

//        guard areToolsEnabled, !tools.isEmpty else {
//            return session.streamResponse(to: message, attachments: attachments)
//        }
//
//        return AsyncThrowingStream { continuation in
//            Task {
//                do {
//                    let response = try await session.respond(to: message, attachments: attachments)
//                    // Send the full response as chunks
//                    for char in response {
//                        continuation.yield(String(char))
//                    }
//                    continuation.finish()
//                } catch {
//                    continuation.finish(throwing: error)
//                }
//            }
//        }
    }
    
    func toggleTools() async {
        areToolsEnabled.toggle()
        if session != nil {
            await loadLLM() // Reload session with/without tools
        }
    }
}

#if DEBUG
extension AI {
    func setSession(_ session: LLMSession) {
        self.session = session
    }
}
#endif
