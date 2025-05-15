import Foundation
#if BUILD_DOCC
@preconcurrency @_implementationOnly import llama
#else
@preconcurrency private import llama
#endif
import LocalLLMClient

public struct Generator: AsyncSequence, @unchecked Sendable {
    public init(context: Context) {
        self.context = context
    }

    let context: Context

    public func makeAsyncIterator() -> TokenGenerator {
        TokenGenerator(context: context)
    }
}

public struct TokenGenerator: AsyncIteratorProtocol {
    init(context: Context) {
        self.context = context
    }

    private let context: Context
    private var iteration = 0
    private var temporaryInvalidCharacters: [CChar] = []

    mutating public func next() throws -> String? {
        if Task.isCancelled {
            return nil
        }

        try context.decode()

        let newTokenId = context.sampling.sample(context: context, index: -1)

        if llama_vocab_is_eog(context.vocab, newTokenId) || context.position >= context.parameter.context {
            if iteration > 0, temporaryInvalidCharacters.isEmpty {
                return nil
            } else {
                let newToken = String(utf8String: temporaryInvalidCharacters + [0]) ?? ""
                temporaryInvalidCharacters.removeAll()
                return newToken
            }
        }

        temporaryInvalidCharacters.append(contentsOf: newTokenId.piece(vocab: context.vocab, special: true))

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

        if context.extraEOSTokens.contains(newToken) {
            if iteration > 0 {
                temporaryInvalidCharacters.removeAll()
                return nil
            }
        }

        context.batch.add(id: newTokenId, pos: context.position, seq_ids: [0], logits: true)

        iteration += 1
        return newToken
    }
}
