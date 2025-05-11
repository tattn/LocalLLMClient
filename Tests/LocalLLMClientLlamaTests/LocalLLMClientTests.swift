import Testing
import Foundation
import LocalLLMClient
import LocalLLMClientLlama
import LocalLLMClientUtility

private let disabledTests = ![nil, "Llama"].contains(ProcessInfo.processInfo.environment["GITHUB_ACTIONS_TEST"])

extension LocalLLMClient {
    static let model = "SmolVLM-256M-Instruct-Q8_0.gguf"
    static let clip = "mmproj-SmolVLM-256M-Instruct-Q8_0.gguf"

    static func llama(parameter: LlamaClient.Parameter? = nil) async throws -> LlamaClient {
        let url = try await downloadModel()
        return try await LocalLLMClient.llama(
            url: url.appending(component: model),
            clipURL: url.appending(component: clip),
            parameter: parameter ?? .init(
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

private let prompt = "<|im_start|>user\nWhat is the answer to one plus two?<|im_end|>\n<|im_start|>assistant\n"

@Suite(.serialized, .disabled(if: disabledTests))
actor LocalLLMClientTests {
    private static var initialized = false

    init() async throws {
        if !Self.initialized && !disabledTests {
            _ = try await LocalLLMClient.downloadModel()
            Self.initialized = true
        }
    }

    @Test(.timeLimit(.minutes(5)))
    func simpleStream() async throws {
        var result = ""

        for try await text in try await LocalLLMClient.llama().textStream(from: prompt) {
            print(text, terminator: "")
            result += text
        }

        #expect(!result.isEmpty)
    }

    @Test(.timeLimit(.minutes(5)))
    func image() async throws {
        let stream = try await LocalLLMClient.llama().textStream(from: LLMInput(
            .plain("<|im_start|>user\nWhat is in this image?<|im_end|>\n<|im_start|>assistant\n"),
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
            for try await _ in try await LocalLLMClient.llama().textStream(from: prompt) {
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

    @Test(.timeLimit(.minutes(5)))
    func json() async throws {
        var result = ""

        for _ in 0...2 {
            do {
                let input = LLMInput.chat([
                    .system("You are a helpful assistant."),
                    .user("What is the answer to one plus two?\nRespond in JSON.\n\n{ \"answer\": \"<answer>\" }\n")
                ])
                for try await text in try await LocalLLMClient.llama(parameter: .init(
                    temperature: 1.0,
                    penaltyRepeat: 1.3,
                    options: .init(responseFormat: .json)
                )).textStream(from: input) {
                    print(text, terminator: "")
                    result += text
                }

                try JSONSerialization.jsonObject(with: Data(result.utf8), options: [])
                return
            } catch {
            }
        }

        Issue.record()
    }
}
