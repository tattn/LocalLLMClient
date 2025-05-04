import Testing
import Foundation
import LocalLLMClient
import LocalLLMClientLlama
import LocalLLMClientUtility

extension LocalLLMClient {
    static let model = "gemma-3-4b-it-Q3_K_L.gguf"
    static let clip = "mmproj-model-f16.gguf"
    static func llama() async throws -> LlamaClient {
        let url = try await downloadModel()
        return try await LocalLLMClient.llama(
            url: url.appending(component: model),
            clipURL: url.appending(component: clip),
            verbose: true
        )
    }

    static func downloadModel() async throws -> URL {
        let downloader = FileDownloader(
            source: .huggingFace(id: "lmstudio-community/gemma-3-4b-it-GGUF", globs: [model, clip])
            destination: ProcessInfo.processInfo.environment["GITHUB_MODEL_CACHE"].flatMap(URL.init(string:)) ?? FileDownloader.defaultRootDestination
        )
        return try await downloader.download { print("Download: \($0)") }
    }
}

@Test func simple() async throws {
    let client = try await LocalLLMClient.llama()
    let input = "What is the answer to one plus two?"

    let result = try await client.generateText(from: input)
    print(result)

    #expect(!result.isEmpty)
}

@Test func simpleStream() async throws {
    let client = try await LocalLLMClient.llama()
    let input = "What is the answer to one plus two?"

    var result = ""
    for try await text in try await client.textStream(from: input) {
        print(text)
        result += text
    }

    #expect(!result.isEmpty)
}
