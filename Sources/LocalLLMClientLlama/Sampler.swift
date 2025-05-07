@preconcurrency import llama

typealias Sampler = UnsafeMutablePointer<llama_sampler>

package extension Sampler {
    func sample(context: Context, index: Int32) -> llama_token {
        let logits = llama_get_logits_ith(context.context, Int32(index))!

        for tokenID in 0..<context.cursor.count {
            let logit = logits[tokenID]
            context.cursor[tokenID] = llama_token_data(id: Int32(tokenID), logit: logit, p: 0.0)
        }

        var tokenDataArray = context.cursor.withUnsafeMutableBufferPointer { buffer in
            llama_token_data_array(
                data: buffer.baseAddress,
                size: buffer.count,
                selected: -1,
                sorted: false
            )
        }

        if let grammer = context.grammer {
            llama_sampler_apply(grammer, &tokenDataArray)
        }

        llama_sampler_apply(self, &tokenDataArray)
        assert(tokenDataArray.selected != -1)

        let token = tokenDataArray.data[Int(tokenDataArray.selected)].id
        llama_sampler_accept(self, token)
        return token
    }
}
