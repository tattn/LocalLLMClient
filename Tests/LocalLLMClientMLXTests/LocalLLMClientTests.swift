import Testing
import Foundation
import LocalLLMClient
import LocalLLMClientMLX
import LocalLLMClientUtility

extension LocalLLMClient {
    static func mlx() async throws -> MLXClient {
        try await LocalLLMClient.mlx(url: downloadModel(), parameter: .init(maxTokens: 256))
    }

    static func downloadModel() async throws -> URL {
        let downloader = FileDownloader(
            source: .huggingFace(id: "mlx-community/SmolVLM2-256M-Video-Instruct-mlx", globs: .mlx),
            destination: ProcessInfo.processInfo.environment["GITHUB_MODEL_CACHE"].map { URL(filePath: $0) } ?? FileDownloader.defaultRootDestination
        )
        return try await downloader.download { print("Download: \($0)") }
    }
}

@Suite(.serialized) struct LocalLLMClientTests {
    @Test func simpleStream() async throws {
        let input = "What is the answer to one plus two?"
        var result = ""
        for try await text in try await LocalLLMClient.mlx().textStream(from: input) {
            print(text, terminator: "")
            result += text
        }

        #expect(!result.isEmpty)
    }

    @Test func image() async throws {
        let client = try await LocalLLMClient.mlx()

        let stream = try await client.textStream(from: LLMInput(
            prompt: "What is in this image?",
            attachments: [.image(.init(contentsOf: URL(string: "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/cats.jpeg")!)!)]
        ))
        var result = ""
        for try await text in stream {
            print(text, terminator: "")
            result += text
        }

        #expect(!result.isEmpty)
    }
}
