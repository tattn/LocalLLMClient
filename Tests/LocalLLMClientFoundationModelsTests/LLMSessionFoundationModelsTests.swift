#if canImport(FoundationModels)
import Testing
import Foundation
import LocalLLMClient
import LocalLLMClientFoundationModels

extension ModelTests {
    struct LLMSessionFoundationModelsTests {}
}

extension ModelTests.LLMSessionFoundationModelsTests {
    @available(macOS 26.0, *)
    @Test(.timeLimit(.minutes(5)))
    func simpleRespond() async throws {
        let session = LLMSession(model: .foundationModels())
        print(try await session.respond(to: "1 + 2 = ?"))
        print(try await session.respond(to: "What is the previous answer plus 4?"))
    }

    @available(macOS 26.0, *)
    @Test(.timeLimit(.minutes(5)))
    func simpleStreamResponse() async throws {
        let session = LLMSession(model: .foundationModels())
        for try await text in session.streamResponse(to: "What is 1 plus 2?") {
            print(text, terminator: "")
        }
        for try await text in session.streamResponse(to: "What is the previous answer plus 4?") {
            print(text, terminator: "")
        }
    }
}
#endif
