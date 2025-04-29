import llama

extension [llama_token] {
    init(_ text: String, add_bos: Bool, vocab: OpaquePointer) {
        let utf8Count = text.utf8.count
        let n_tokens = utf8Count + (add_bos ? 1 : 0) + 1
        self.init(unsafeUninitializedCapacity: n_tokens) { buffer, initializedCount in
            let count = llama_tokenize(vocab, text, Int32(utf8Count), buffer.baseAddress, Int32(n_tokens), add_bos, false)
            initializedCount = Int(count)
        }
    }
}

extension llama_token {
    func piece(vocab: OpaquePointer) -> [CChar] {
        let result = UnsafeMutablePointer<Int8>.allocate(capacity: 8)
        result.initialize(repeating: Int8(0), count: 8)
        defer {
            result.deallocate()
        }
        let nTokens = llama_token_to_piece(vocab, self, result, 8, 0, false)

        if nTokens < 0 {
            let newResult = UnsafeMutablePointer<Int8>.allocate(capacity: Int(-nTokens))
            newResult.initialize(repeating: Int8(0), count: Int(-nTokens))
            defer {
                newResult.deallocate()
            }
            let nNewTokens = llama_token_to_piece(vocab, self, newResult, -nTokens, 0, false)
            let bufferPointer = UnsafeBufferPointer(start: newResult, count: Int(nNewTokens))
            return Array(bufferPointer)
        } else {
            let bufferPointer = UnsafeBufferPointer(start: result, count: Int(nTokens))
            return Array(bufferPointer)
        }
    }
}
