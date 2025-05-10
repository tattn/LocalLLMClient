@preconcurrency import llama
import LocalLLMClient

public extension Context {
    @discardableResult
    func decode() throws(LLMError) -> Int32 {
        let numberOfTokens = batch.n_tokens
        guard batch.n_tokens > 0 else {
            return 0 // no data to decode
        }

        batch.logits[Int(batch.n_tokens) - 1] = 1

        guard llama_decode(context, batch) == 0 else {
            throw .decodingFailed
        }

        batch.clear()

        return numberOfTokens
    }

    func evaluate(with tokens: [llama_token], context: DecodingContext) -> DecodingContext {
        for (index, token) in tokens.enumerated() {
            batch.add(id: token, pos: llama_pos(index) + context.cursor, seq_ids: [0], logits: false)
        }
        var context = context
        context.cursor += Int32(tokens.count)
        return context
    }

    func decode(text: String, context: DecodingContext) throws(LLMError) -> DecodingContext {
        let tokens = [llama_token](text, add_bos: addBos, special: context.special, vocab: vocab)
        let context = evaluate(with: tokens, context: context)
        try decode()
        return context
    }
}

public struct DecodingContext: Sendable {
    public init(cursor: llama_pos, special: Bool) {
        self.cursor = cursor
        self.special = special
    }

    public var cursor: llama_pos
    public var special: Bool
}
