import Testing
import Foundation
import LocalLLMClientCore
@testable import LocalLLMClientLlama

extension ModelTests {
    struct ContextTests {}
}

extension ModelTests.ContextTests {

    @Test
    func verifyContext() async throws {
        try await verifyContext(withText: "Hello, world!")
    }

    @Test
    func verifyContextMultibytes() async throws {
        try await verifyContext(withText: "こんにちは, 世界！")
    }

    private func verifyContext(withText text: String) async throws {
        let client = try await LocalLLMClient.llama()
        let context = client._context
        let textTokens = [llama_token](text, addBos: false, special: true, vocab: context.vocab)
        var expectedPosition = textTokens.count

        #expect(context.position == 0)
        try context.decode(text: text)
        #expect(context.position == expectedPosition)

        _ = context.sampling.sample(context: context, index: context.position - 1)
        var token = context.sampling.sample(context: context, index: -1)
        var pieces = token.piece(vocab: context.vocab, special: true)
        while String(utf8String: pieces + [0]) == nil {
            context.batch.add(id: token, pos: context.position, seq_ids: [0], logits: true)

            #expect(context.position == expectedPosition)
            try context.decode()
            expectedPosition += 1
            #expect(context.position == expectedPosition)

            token = context.sampling.sample(context: context, index: -1)
            pieces.append(contentsOf: token.piece(vocab: context.vocab, special: true))
        }
    }
}
