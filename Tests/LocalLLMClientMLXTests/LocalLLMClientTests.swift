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

let prompt = "What is the answer to one plus two?"

@Suite(.serialized) actor LocalLLMClientTests {
    private static var initialized = false

    init() async throws {
        if !Self.initialized {
            _ = try await LocalLLMClient.downloadModel()
            Self.initialized = true
        }
    }

    @Test(.timeLimit(.minutes(5)))
    func simpleStream() async throws {
        var result = ""
        for try await text in try await LocalLLMClient.mlx().textStream(from: prompt) {
            print(text, terminator: "")
            result += text
        }

        #expect(!result.isEmpty)
    }

    @Test(.timeLimit(.minutes(5)))
    func image() async throws {
        let stream = try await LocalLLMClient.mlx().textStream(from: LLMInput(
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

    @Test(.timeLimit(.minutes(5)))
    func cancel() async throws {
        var counter = 0
        var breaked = false

        var task: Task<Void, Error>?
        task = Task {
            for try await _ in try await LocalLLMClient.mlx().textStream(from: prompt) {
                counter += 1
                task?.cancel()
            }
            breaked = true
        }

        try await Task.sleep(for: .seconds(2))
        task!.cancel()
        try? await task!.value

        #expect(counter == 1)
        #expect(breaked)
    }
}
