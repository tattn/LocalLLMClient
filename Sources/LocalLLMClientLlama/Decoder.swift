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
        let startPosition = position
        let tokens = [llama_token](text, addBos: false, special: true, vocab: vocab)

        // Split tokens into chunks based on parameter.batch to avoid buffer overflow
        let chunkSize = parameter.batch
        let chunks = stride(from: 0, to: tokens.count, by: chunkSize).map {
            tokens[$0..<min($0 + chunkSize, tokens.count)]
        }

        for (chunkIndex, chunk) in chunks.enumerated() {
            let chunkOffset = startPosition + llama_pos(chunkIndex * chunkSize)
            for (index, token) in chunk.enumerated() {
                batch.add(id: token, pos: chunkOffset + llama_pos(index), seq_ids: [0], logits: false)
            }
            try decode()
        }
    }
}
