#if BUILD_DOCC
@preconcurrency @_implementationOnly import llama
#elseif canImport(llama)
@preconcurrency private import llama
#else
@preconcurrency import LocalLLMClientLlamaC
#endif
import LocalLLMClientCore

public extension Context {
    @discardableResult
    func decode() throws(LLMError) -> Int32 {
        let numberOfTokens = batch.n_tokens
        guard batch.n_tokens > 0 else {
            return 0 // no data to decode
        }

        if parameter.context < position + batch.n_tokens {
            throw LLMError.failedToDecode(reason: "context size exceeded")
        }

        batch.logits[Int(batch.n_tokens) - 1] = 1

        guard llama_decode(context, batch) == 0 else {
            throw .failedToDecode(reason: "batch decode failed")
        }

        batch.clear()

        return numberOfTokens
    }

    func decode(text: String) throws(LLMError) {
        let startPosition = position
        let tokens = [llama_token](text, addBos: false, special: true, vocab: vocab)

        // Split tokens into chunks based on parameter.batch to avoid buffer overflow
        let chunkSize = parameter.batch
        for chunkStart in stride(from: 0, to: tokens.count, by: chunkSize) {
            let chunk = tokens[chunkStart..<min(chunkStart + chunkSize, tokens.count)]

            let chunkOffset = startPosition + llama_pos(chunkStart)
            for (index, token) in chunk.enumerated() {
                batch.add(id: token, pos: chunkOffset + llama_pos(index), seq_ids: [0], logits: false)
            }
            try decode()
        }
    }
}
