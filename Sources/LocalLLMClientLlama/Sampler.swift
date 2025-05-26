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
        let logits = UncheckedSendable(llama_get_logits_ith(context.context, Int32(index))!)

        DispatchQueue.concurrentPerform(iterations: context.cursorPointer.count) { tokenID in
            context.cursorPointer[tokenID] = llama_token_data(
                id: Int32(tokenID), logit: logits.value[tokenID], p: 0.0
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

        let token = tokenDataArray.data[Int(tokenDataArray.selected)].id
        llama_sampler_accept(self, token)
        return token
    }
}

private struct UncheckedSendable<Value>: @unchecked Sendable {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
