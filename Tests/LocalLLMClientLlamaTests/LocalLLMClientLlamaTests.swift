import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import LocalLLMClientCore
import LocalLLMClientLlama

private let prompt = "<|im_start|>user\nWhat is the answer to one plus two?<|im_end|>\n<|im_start|>assistant\n"

extension ModelTests {
    struct LocalLLMClientLlamaTests {}
}

extension ModelTests.LocalLLMClientLlamaTests {
    @Test
    func simpleStream() async throws {
        var result = ""

        for try await text in try await LocalLLMClient.llama().textStream(from: prompt) {
            print(text, terminator: "")
            result += text
        }

        #expect(!result.isEmpty)
    }

    @Test
    func image() async throws {
        let stream = try await LocalLLMClient.llama().textStream(from: LLMInput(
            .chat([.user("<|test_img|>What is in this image?", attachments: [
                .image(.init(data: Data(contentsOf: URL(string: "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/cats.jpeg")!))!)
            ])]),
        ))

        var result = ""
        for try await text in stream {
            print(text, terminator: "")
            result += text
        }

        #expect(!result.isEmpty)
    }

    @Test @MainActor
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

        try await Task.sleep(for: .seconds(5))
        task!.cancel()
        try? await task!.value

        #expect(counter == 1)
        #expect(breaked)
    }

    @Test
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
                print(error)
            }
        }

        Issue.record()
    }

    @Test
    func overflowBatchSize() async throws {
        let result = try await LocalLLMClient.llama(parameter: .init(context: 512, batch: 2, options: .init(verbose: true))).generateText(from: "Hello, world!")
        #expect(!result.isEmpty)
    }
}
