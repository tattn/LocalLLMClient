#if BUILD_DOCC
@preconcurrency @_implementationOnly import llama
#else
@preconcurrency private import llama
#endif
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

    func decode(text: String) throws(LLMError) {
        let position = position
        let addBos = needsAddBos && position == 0
        let tokens = [llama_token](text, addBos: addBos, special: true, vocab: vocab)
        for (index, token) in tokens.enumerated() {
            batch.add(id: token, pos: llama_pos(index) + position, seq_ids: [0], logits: false)
        }
        try decode()
    }
}
