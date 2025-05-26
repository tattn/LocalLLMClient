#if BUILD_DOCC
@preconcurrency @_implementationOnly import llama
#elseif canImport(llama)
@preconcurrency private import llama
#else
@preconcurrency import LocalLLMClientLlamaC
#endif

package extension llama_batch {
    mutating func clear() {
        n_tokens = 0
    }

    mutating func add(id: llama_token, pos: llama_pos, seq_ids: [llama_seq_id], logits: Bool) {
        self.token[Int(n_tokens)] = id
        self.pos[Int(n_tokens)] = pos
        self.n_seq_id[Int(n_tokens)] = Int32(seq_ids.count)

        for i in 0..<seq_ids.count {
            self.seq_id[Int(n_tokens)]![Int(i)] = seq_ids[i]
        }

        self.logits[Int(n_tokens)] = logits ? 1 : 0

        self.n_tokens += 1
    }
}
