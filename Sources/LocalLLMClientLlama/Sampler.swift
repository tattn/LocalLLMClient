#if BUILD_DOCC
@preconcurrency @_implementationOnly import llama
#elseif canImport(llama)
@preconcurrency private import llama
#else
@preconcurrency import LocalLLMClientLlamaC
#endif
import Foundation

typealias Sampler = UnsafeMutablePointer<llama_sampler>

package extension Sampler {
    func sample(context: Context, index: Int32) -> llama_token {
        let logits = llama_get_logits_ith(context.context, index)!

        for tokenID in context.cursorPointer.indices { // faster than using range
            context.cursorPointer[tokenID] = llama_token_data(
                id: Int32(tokenID), logit: logits[tokenID], p: 0.0
            )
        }

        var tokenDataArray = llama_token_data_array(
            data: context.cursorPointer.baseAddress,
            size: context.cursorPointer.count,
            selected: -1,
            sorted: false
        )

        if let grammer = context.grammer {
            llama_sampler_apply(grammer, &tokenDataArray)
        }

        llama_sampler_apply(self, &tokenDataArray)
        assert(tokenDataArray.selected != -1)

        var data = tokenDataArray.data[Int(tokenDataArray.selected)]
        if data.logit.isInfinite {
            if let grammer = context.grammer {
                llama_sampler_apply(grammer, &tokenDataArray)
            }
            llama_sampler_apply(self, &tokenDataArray)
            data = tokenDataArray.data[Int(tokenDataArray.selected)]
            assert(tokenDataArray.selected != -1)
        }
        let token = data.id
        llama_sampler_accept(self, token)
        return token
    }
}
