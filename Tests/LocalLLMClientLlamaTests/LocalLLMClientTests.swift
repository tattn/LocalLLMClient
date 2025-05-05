import Testing
import Foundation
import LocalLLMClient
import LocalLLMClientLlama
import LocalLLMClientUtility

extension LocalLLMClient {
    static let model = "SmolVLM-256M-Instruct-Q8_0.gguf"
    static let clip = "mmproj-SmolVLM-256M-Instruct-Q8_0.gguf"

    static func llama() async throws -> LlamaClient {
        let url = try await downloadModel()
        return try await LocalLLMClient.llama(
            url: url.appending(component: model),
            clipURL: url.appending(component: clip),
            parameter: .init(
                context: 512,
                tokenImageStart: "<|im_start|>user\n", tokenImageEnd: "<|im_end|>\n"
            ),
            verbose: true
        )
    }

    static func downloadModel() async throws -> URL {
        let downloader = FileDownloader(
            source: .huggingFace(id: "ggml-org/SmolVLM-256M-Instruct-GGUF", globs: [model, clip]),
            destination: ProcessInfo.processInfo.environment["GITHUB_MODEL_CACHE"].map { URL(filePath: $0) } ?? FileDownloader.defaultRootDestination
        )
        return try await downloader.download { print("Download: \($0)") }
    }
}

@Test func simpleStream() async throws {
    let client = try await LocalLLMClient.llama()
    let input = "<|im_start|>user\nWhat is the answer to one plus two?<|im_end|>\n<|im_start|>assistant\n"

    var result = ""
    for try await text in try await client.textStream(from: input) {
        print(text, terminator: "")
        result += text
    }

    #expect(!result.isEmpty)
}

@Test func image() async throws {
    let client = try await LocalLLMClient.llama()

    let stream = try client.textStream(from: LLMInput(
        prompt: "<|im_start|>user\nWhat is in this image?<|im_end|>\n<|im_start|>assistant\n",
        attachments: [.image(.init(contentsOf: URL(string: "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/cats.jpeg")!)!)]
    ))
    var result = ""
    for try await text in stream {
        print(text, terminator: "")
        result += text
    }

    #expect(!result.isEmpty)
}
