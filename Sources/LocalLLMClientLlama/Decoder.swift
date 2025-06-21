#if BUILD_DOCC
@preconcurrency @_implementationOnly import llama
#elseif canImport(llama)
@preconcurrency private import llama
#else
@preconcurrency import LocalLLMClientLlamaC
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
            throw .failedToDecode(reason: "batch decode failed")
        }

        batch.clear()

        return numberOfTokens
    }

    func decode(text: String) throws(LLMError) {
        let position = position
        let tokens = [llama_token](text, addBos: false, special: true, vocab: vocab)
        for (index, token) in tokens.enumerated() {
            batch.add(id: token, pos: llama_pos(index) + position, seq_ids: [0], logits: false)
            if batch.n_tokens == parameter.batch {
                try decode()
            }
        }
        try decode()
    }
}
