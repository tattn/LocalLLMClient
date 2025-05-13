import Testing
import Foundation
import LocalLLMClient
import LocalLLMClientMLX
import LocalLLMClientUtility

private let disabledTests = ![nil, "MLX"].contains(ProcessInfo.processInfo.environment["GITHUB_ACTIONS_TEST"])

extension LocalLLMClient {
    static func mlx() async throws -> MLXClient {
        try await LocalLLMClient.mlx(url: downloadModel(), parameter: .init(maxTokens: 256))
    }

    static func downloadModel() async throws -> URL {
        let downloader = FileDownloader(
            source: .huggingFace(id: "mlx-community/SmolVLM2-256M-Video-Instruct-mlx", globs: .mlx),
            destination: ProcessInfo.processInfo.environment["GITHUB_MODEL_CACHE"].map { URL(filePath: $0) } ?? FileDownloader.defaultRootDestination
        )
        try await downloader.download { print("Download: \($0)") }
        return downloader.destination
    }
}

@Suite(.serialized, .disabled(if: disabledTests))
actor ModelTests {
    private static var initialized = false

    init() async throws {
        if !Self.initialized && !disabledTests {
            _ = try await LocalLLMClient.downloadModel()
            Self.initialized = true
        }
    }
}
