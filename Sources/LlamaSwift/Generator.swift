import Foundation
@preconcurrency import llama

public struct Generator: AsyncSequence {
    public init(text: String, context: Context, cursor: Int32 = 0, special: Bool = false) {
        self.text = text
        self.context = context
        self.cursor = cursor
        self.special = special
    }

    let text: String
    let context: Context
    let cursor: Int32
    let special: Bool

    public func makeAsyncIterator() -> TokenGenerator {
        TokenGenerator(text: text, context: context, cursor: cursor, special: special)
    }
}

public struct TokenGenerator: AsyncIteratorProtocol {
    init(text: String, context: Context, cursor: Int32, special: Bool) {
        let tokens = [llama_token](text, add_bos: true, special: special, vocab: context.vocab)
        self.cursor = context.evaluate(with: tokens, cursor: cursor)
        self.context = context
        self.special = special
    }

    private let context: Context
    private var cursor: Int32
    private var iteration = 0
    private var temporaryInvalidCharacters: [CChar] = []
    private let special: Bool

    mutating public func next() async throws -> String? {
        try Task.checkCancellation()
        try context.decode()

        let newTokenId = context.sampling.sample(context: context, index: -1)

        if llama_vocab_is_eog(context.vocab, newTokenId) || cursor >= context.parameter.context {
            if iteration > 0, temporaryInvalidCharacters.isEmpty {
                return nil
            } else {
                let newToken = String(utf8String: temporaryInvalidCharacters + [0]) ?? ""
                temporaryInvalidCharacters.removeAll()
                return newToken
            }
        }

        temporaryInvalidCharacters.append(contentsOf: newTokenId.piece(vocab: context.vocab, special: special))

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

        context.batch.add(id: newTokenId, pos: llama_pos(cursor), seq_ids: [0], logits: true)

        cursor += 1
        iteration += 1
        return newToken
    }
}
