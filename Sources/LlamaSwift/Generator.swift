import Foundation
@preconcurrency import llama

public struct Generator: AsyncSequence {
    public init(text: String, context: Context) {
        self.text = text
        self.context = context
    }

    let text: String
    let context: Context

    public func makeAsyncIterator() -> TokenGenerator {
        TokenGenerator(text: text, context: context)
    }
}

public struct TokenGenerator: AsyncIteratorProtocol {
    init(text: String, context: Context) {
        let tokens = [llama_token](text, add_bos: true, vocab: context.vocab)

        context.batch.clear()

        for (index, token) in tokens.enumerated() {
            context.batch.add(id: token, pos: llama_pos(index), seq_ids: [0], logits: false)
        }
        context.batch.logits[Int(context.batch.n_tokens) - 1] = 1

        self.cursor = context.batch.n_tokens
        self.context = context
    }

    private let context: Context
    private var cursor: Int32
    private var temporaryInvalidCharacters: [CChar] = []

    mutating public func next() async throws -> String? {
        try Task.checkCancellation()

        guard llama_decode(context.context, context.batch) == 0 else {
            throw Error.decodingFailed
        }

        let newTokenId = context.sampling.sample(context: context, index: -1)

        if llama_vocab_is_eog(context.vocab, newTokenId) || cursor == context.parameter.maxTokenLength {
            if temporaryInvalidCharacters.isEmpty {
                return nil
            } else {
                let newToken = String(utf8String: temporaryInvalidCharacters + [0]) ?? ""
                temporaryInvalidCharacters.removeAll()
                return newToken
            }
        }

        temporaryInvalidCharacters.append(contentsOf: newTokenId.piece(vocab: context.vocab))

        let newToken: String
        if let token = String(utf8String: temporaryInvalidCharacters + [0]) {
            temporaryInvalidCharacters.removeAll()
            newToken = token
        } else if (1 ..< temporaryInvalidCharacters.count).contains(where: { String(utf8String: Array(temporaryInvalidCharacters.suffix($0)) + [0]) != nil }) {
            let token = String(utf8String: temporaryInvalidCharacters + [0]) ?? ""
            temporaryInvalidCharacters.removeAll()
            newToken = token
        } else {
            newToken = ""
        }

        context.batch.clear()
        context.batch.add(id: newTokenId, pos: llama_pos(cursor), seq_ids: [0], logits: true)

        cursor += 1
        return newToken
    }
}
