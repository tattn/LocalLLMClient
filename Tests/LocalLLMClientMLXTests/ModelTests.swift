import Testing
import Foundation
import LocalLLMClientCore
import LocalLLMClientMLX
import LocalLLMClientUtility
import LocalLLMClientTestUtilities

private let disabledTests = ![nil, "MLX"].contains(ProcessInfo.processInfo.environment["GITHUB_ACTIONS_TEST"])

extension LocalLLMClient {
    enum TestType {
        case tool
        case general
    }
    
    enum ModelSize {
        case light
        case normal
        
        static var `default`: ModelSize {
            if TestEnvironment.onGitHubAction {
                return .light
            } else {
                return .normal
            }
        }
    }
    
    static func modelInfo(for testType: TestType, modelSize: ModelSize = .default) -> String {
        let size = modelSize
        
        switch testType {
        case .tool:
//            switch size {
//            case .light:
//                return "mlx-community/Qwen2.5-0.5B-Instruct-8bit"
//            case .normal:
                return "mlx-community/Qwen2.5-1.5B-Instruct-8bit"
//            }
        case .general:
            switch size {
            case .light, .normal:
                return "mlx-community/SmolVLM2-256M-Video-Instruct-mlx"
            }
        }
    }
    
    static func mlx(
        parameter: MLXClient.Parameter? = nil,
        testType: TestType = .general,
        modelSize: ModelSize = .default,
        tools: [any LLMTool] = []
    ) async throws -> MLXClient {
        let url = try await downloadModel(testType: testType, modelSize: modelSize)
        return try await LocalLLMClient.mlx(
            url: url,
            parameter: parameter ?? .init(maxTokens: 512),
            tools: tools
        )
    }

    static func downloadModel(testType: TestType = .general, modelSize: ModelSize = .default) async throws -> URL {
        let modelId = modelInfo(for: testType, modelSize: modelSize)
        let downloader = FileDownloader(
            source: .huggingFace(id: modelId, globs: .mlx),
            destination: ProcessInfo.processInfo.environment["GITHUB_MODEL_CACHE"].map { URL(filePath: $0) } ?? FileDownloader.defaultRootDestination
        )
        try await downloader.download { print("Download: \($0)") }
        return downloader.destination
    }
}

@Suite(.serialized, .timeLimit(.minutes(5)), .disabled(if: disabledTests))
actor ModelTests {
    nonisolated(unsafe) private static var initialized = false

    init() async throws {
        if !Self.initialized && !disabledTests {
            // Determine which models need to be downloaded
            let modelConfigs: [(testType: LocalLLMClient.TestType, modelSize: LocalLLMClient.ModelSize)] = [
                (.general, LocalLLMClient.ModelSize.default),  // Default size for general tests
                (.general, .light),                           // Light model for template tests
                (.tool, LocalLLMClient.ModelSize.default)     // Default size for tool tests
            ]
            
            // Download required models
            await withTaskGroup(of: Void.self) { group in
                for config in modelConfigs {
                    group.addTask {
                        do {
                            _ = try await LocalLLMClient.downloadModel(testType: config.testType, modelSize: config.modelSize)
                            let modelId = LocalLLMClient.modelInfo(for: config.testType, modelSize: config.modelSize)
                            print("Downloaded \(config.testType) \(config.modelSize) model: \(modelId)")
                        } catch {
                            print("Failed to download \(config.testType) \(config.modelSize) model: \(error)")
                        }
                    }
                }
            }
            
            Self.initialized = true
        }
    }
}
