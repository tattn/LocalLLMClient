#if BUILD_DOCC
@preconcurrency @_implementationOnly import llama
#elseif canImport(llama)
@preconcurrency private import llama
#else
@preconcurrency import LocalLLMClientLlamaC
#endif

package extension [llama_token] {
    init(_ text: String, addBos: Bool, special: Bool, vocab: OpaquePointer) {
        let utf8Count = text.utf8.count
        let n_tokens = utf8Count + (addBos ? 1 : 0) + 1
        self.init(unsafeUninitializedCapacity: n_tokens) { buffer, initializedCount in
            let count = llama_tokenize(vocab, text, Int32(utf8Count), buffer.baseAddress, Int32(n_tokens), addBos, special)
            initializedCount = Int(count)
        }
    }
}

package extension llama_token {
    func piece(vocab: OpaquePointer, special: Bool) -> [CChar] {
        var result = [CChar](repeating: 0, count: 8)
        let nTokens = llama_token_to_piece(vocab, self, &result, 8, 0, special)
        if nTokens < 0 {
            result = [CChar](repeating: 0, count: Int(-nTokens))
            llama_token_to_piece(vocab, self, &result, -nTokens, 0, special)
            return result
        } else {
            return Array(result[0..<Int(nTokens)])
        }
    }
}
