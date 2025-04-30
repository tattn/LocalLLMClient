@preconcurrency import llama
import LLMCommon

package extension Context {
    func decode() throws(LLMError) {
        guard batch.n_tokens > 0 else {
            return // no data to decode
        }

        batch.logits[Int(batch.n_tokens) - 1] = 1

        guard llama_decode(context, batch) == 0 else {
            throw .decodingFailed
        }

        batch.clear()
    }

    func evaluate(with tokens: [llama_token], cursor: llama_pos) -> llama_pos {
        for (index, token) in tokens.enumerated() {
            batch.add(id: token, pos: llama_pos(index) + batch.n_tokens + cursor, seq_ids: [0], logits: false)
        }
        return batch.n_tokens + cursor
    }

    func decode(text: String, cursor: llama_pos, special: Bool = false) throws(LLMError) -> llama_pos {
        let tokens = [llama_token](text, add_bos: addBos, special: special, vocab: vocab)
        let result = evaluate(with: tokens, cursor: cursor)
        try decode()
        return result
    }
}
