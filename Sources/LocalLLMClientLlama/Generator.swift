import Foundation
#if BUILD_DOCC
@preconcurrency @_implementationOnly import llama
#elseif canImport(llama)
@preconcurrency private import llama
#else
@preconcurrency import LocalLLMClientLlamaC
#endif
import LocalLLMClientCore

public struct Generator: AsyncSequence, Sendable {
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
    private var temporaryInvalidCharacters: [CChar] = []
    private var currentResult = ""

    mutating public func next() async throws -> String? {
        if Task.isCancelled {
            updatePromptCache()
            return nil
        }

        try context.decode()

        let newTokenId = context.sampling.sample(context: context, index: -1)

        if llama_vocab_is_eog(context.vocab, newTokenId) || context.position >= context.parameter.context {
            if temporaryInvalidCharacters.isEmpty {
                updatePromptCache()
                return nil
            } else {
                let newToken = makeString() ?? ""
                temporaryInvalidCharacters.removeAll()
                return newToken
            }
        }

        temporaryInvalidCharacters.append(contentsOf: newTokenId.piece(vocab: context.vocab, special: true))

        let newToken: String
        if let token = makeString() {
            temporaryInvalidCharacters.removeAll()
            newToken = token
        } else if (1 ..< temporaryInvalidCharacters.count).contains(where: { String(utf8String: Array(temporaryInvalidCharacters.suffix($0)) + [0]) != nil }) {
            let token = makeString() ?? ""
            temporaryInvalidCharacters.removeAll()
            newToken = token
        } else {
            newToken = ""
        }

        if context.extraEOSTokens.contains(newToken) {
            temporaryInvalidCharacters.removeAll()
            updatePromptCache()
            return nil
        }

        context.batch.add(id: newTokenId, pos: context.position, seq_ids: [0], logits: true)

        return newToken
    }

    private mutating func makeString() -> String? {
        guard let text = String(utf8String: temporaryInvalidCharacters + [0]) else {
            return nil
        }
        currentResult += text
        return text
    }

    private func updatePromptCache() {
        context.addCache(for: .text(currentResult), position: context.position)
    }
}
