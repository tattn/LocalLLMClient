import Foundation
@preconcurrency import llama

public struct Generator: AsyncSequence {
    public init(context: Context, decodeContext: DecodingContext) {
        self.context = context
        self.decodeContext = decodeContext
    }

    let context: Context
    let decodeContext: DecodingContext

    public func makeAsyncIterator() -> TokenGenerator {
        TokenGenerator(context: context, decodeContext: decodeContext)
    }
}

public struct TokenGenerator: AsyncIteratorProtocol {
    init(context: Context, decodeContext: DecodingContext) {
        self.context = context
        self.decodeContext = decodeContext
    }

    private let context: Context
    private var decodeContext: DecodingContext
    private var iteration = 0
    private var temporaryInvalidCharacters: [CChar] = []

    mutating public func next() async throws -> String? {
        try Task.checkCancellation()
        try context.decode()

        let newTokenId = context.sampling.sample(context: context, index: -1)

        if llama_vocab_is_eog(context.vocab, newTokenId) || decodeContext.cursor >= context.parameter.context {
            if iteration > 0, temporaryInvalidCharacters.isEmpty {
                return nil
            } else {
                let newToken = String(utf8String: temporaryInvalidCharacters + [0]) ?? ""
                temporaryInvalidCharacters.removeAll()
                return newToken
            }
        }

        temporaryInvalidCharacters.append(contentsOf: newTokenId.piece(vocab: context.vocab, special: decodeContext.special))

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

        context.batch.add(id: newTokenId, pos: decodeContext.cursor, seq_ids: [0], logits: true)

        decodeContext.cursor += 1
        iteration += 1
        return newToken
    }
}
