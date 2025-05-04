import Testing
import Foundation
import LocalLLMClient
import LocalLLMClientMLX
import LocalLLMClientUtility

extension LocalLLMClient {
    static func mlx() async throws -> MLXClient {
        try await LocalLLMClient.mlx(url: downloadModel())
    }

    static func downloadModel() async throws -> URL {
        let downloader = FileDownloader(
            source: .huggingFace(id: "mlx-community/Qwen2-VL-2B-Instruct-4bit", globs: .mlx),
            destination: ProcessInfo.processInfo.environment["GITHUB_MODEL_CACHE"].map { URL(filePath: $0) } ?? FileDownloader.defaultRootDestination
        )
        return try await downloader.download { print("Download: \($0)") }
    }
}

@Test func simple() async throws {
    let input = "What is the answer to one plus two?"
    let result = try await LocalLLMClient.mlx().generateText(from: input)
    print(result)

    #expect(!result.isEmpty)
}

@Test func simpleStream() async throws {
    let input = "What is the answer to one plus two?"
    var result = ""
    for try await text in try await LocalLLMClient.mlx().textStream(from: input) {
        print(text)
        result += text
    }

    #expect(!result.isEmpty)
}
