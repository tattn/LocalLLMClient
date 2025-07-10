import Testing
import Foundation
import LocalLLMClientCore
import LocalLLMClientMLX

let prompt = "What is the answer to one plus two?"

extension ModelTests {
    struct LocalLLMClientMLXTests {}
}

extension ModelTests.LocalLLMClientMLXTests {
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
            .chat([.user("What is in this image?", attachments: [
                .image(.init(contentsOf: URL(string: "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/cats.jpeg")!)!)
            ])])
        ))
        var result = ""
        for try await text in stream {
            print(text, terminator: "")
            result += text
        }

        #expect(!result.isEmpty)
    }

    @Test(.timeLimit(.minutes(5))) @MainActor
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
