import Testing
import Foundation
import LocalLLMClient
@testable import LocalLLMClientLlama

extension ModelTests {
    struct ContextTests {}
}

extension ModelTests.ContextTests {

    @Test
    func verifyContext() async throws {
        let client = try await LocalLLMClient.llama(parameter: .init(seed: 42))
        let context = client._context
        let text = "Hello, world!"
        let textTokens = [llama_token](text, addBos: false, special: true, vocab: context.vocab)

        #expect(context.position == 0)
        try context.decode(text: text)
        #expect(context.position == textTokens.count)

        #expect(context.sampling.sample(context: context, index: context.position - 1) == 19947)
        let token = context.sampling.sample(context: context, index: -1)
        #expect(token == 17)
        #expect(String(utf8String: token.piece(vocab: context.vocab, special: true) + [0]) == "!")

        context.batch.add(id: token, pos: context.position, seq_ids: [0], logits: true)
        #expect(context.position == textTokens.count)
        try context.decode()
        #expect(context.position == textTokens.count + 1)

        let token2 = context.sampling.sample(context: context, index: -1)
        #expect(token2 == 9617)
        #expect(String(utf8String: token2.piece(vocab: context.vocab, special: true) + [0]) == "</")
    }

    @Test
    func verifyContextMultibytes() async throws {
        let client = try await LocalLLMClient.llama(parameter: .init(seed: 42))
        let context = client._context
        let text = "こんにちは, 世界！"
        let textTokens = [llama_token](text, addBos: false, special: true, vocab: context.vocab)

        #expect(context.position == 0)
        try context.decode(text: text)
        #expect(context.position == textTokens.count)

        #expect(context.sampling.sample(context: context, index: context.position - 1) == 17)
        var token = context.sampling.sample(context: context, index: -1)
        #expect(token == 7365)
        var pieces = token.piece(vocab: context.vocab, special: true)
        #expect(String(utf8String: pieces + [0]) == nil)

        context.batch.add(id: token, pos: context.position, seq_ids: [0], logits: true)
        try context.decode()

        token = context.sampling.sample(context: context, index: -1)
        #expect(token == 228)
        pieces.append(contentsOf: token.piece(vocab: context.vocab, special: true))
        #expect(String(utf8String: pieces + [0]) == "お")
    }
}
