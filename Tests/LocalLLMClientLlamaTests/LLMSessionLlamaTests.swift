import Testing
import Foundation
import LocalLLMClient
import LocalLLMClientLlama

extension ModelTests {
    struct LLMSessionLlamaTests {}
}

extension ModelTests.LLMSessionLlamaTests {
    private func makeModel() -> LLMSession.DownloadModel {
#if true
        .llama(
            id: "ggml-org/SmolVLM-256M-Instruct-GGUF",
            model: "SmolVLM-256M-Instruct-Q8_0.gguf",
            mmproj: "mmproj-SmolVLM-256M-Instruct-Q8_0.gguf"
        )
#else
        .llama(
            id: "lmstudio-community/gemma-3-4B-it-qat-GGUF",
            model: "gemma-3-4B-it-QAT-Q4_0.gguf",
            mmproj: "mmproj-model-f16.gguf"
        )
#endif
    }

    @Test(.timeLimit(.minutes(5)))
    func simpleRespond() async throws {
        let model = makeModel()
        let session = LLMSession(model: model)
        print(try await session.respond(to: "What is 1 plus 2?"))
        print(try await session.respond(to: "What is the previous answer plus 4?"))
    }

    @Test(.timeLimit(.minutes(5)))
    func simpleStreamResponse() async throws {
        let model = makeModel()
        let session = LLMSession(model: model)
        for try await text in session.streamResponse(to: "What is 1 plus 2?") {
            print(text, terminator: "")
        }
        for try await text in session.streamResponse(to: "What is the previous answer plus 4?") {
            print(text, terminator: "")
        }
    }

    @Test(.timeLimit(.minutes(5)))
    func respondWithImage() async throws {
        let model = makeModel()
        let session = LLMSession(model: model)
        print(try await session.respond(to: "What's in this image", attachments: [
            .image(.init(contentsOf: URL(string: "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/cats.jpeg")!)!)
        ]))
    }
}
