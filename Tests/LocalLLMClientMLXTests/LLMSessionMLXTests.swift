import Testing
import Foundation
import LocalLLMClient
import LocalLLMClientMLX

extension ModelTests {
    struct LLMSessionMLXTests {}
}

extension ModelTests.LLMSessionMLXTests {
    private func makeModel() -> LLMSession.DownloadModel {
#if true
        .mlx(id: "mlx-community/SmolVLM2-256M-Video-Instruct-mlx")
#else
        .mlx(id: "mlx-community/Qwen3-4B-4bit")
#endif
    }

    @Test(.timeLimit(.minutes(5)))
    func simpleRespond() async throws {
        let model = makeModel()
        let session = LLMSession(model: model)
        print(try await session.respond(to: "1 + 2 = ?"))
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
}
