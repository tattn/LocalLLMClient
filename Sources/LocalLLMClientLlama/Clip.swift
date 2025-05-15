import Foundation
import LocalLLMClient
@_exported import LocalLLMClientLlamaC

public class ClipModel: @unchecked Sendable {
    package let multimodalContext: OpaquePointer

    public init(url: URL, context: Context, parameter: LlamaClient.Parameter, verbose: Bool = false) throws(LLMError) {
        var mparams = mtmd_context_params_default()
        mparams.use_gpu = true
        mparams.print_timings = verbose
        if let numberOfThreads = parameter.numberOfThreads {
            mparams.n_threads = Int32(numberOfThreads)
        }
        mparams.verbosity = verbose ? GGML_LOG_LEVEL_DEBUG : GGML_LOG_LEVEL_CONT;
        guard let multimodalContext = mtmd_init_from_file(url.path(), context.model.model, mparams) else {
            throw .failedToLoad(reason: "Failed to load multi-modal clip model")
        }
        self.multimodalContext = multimodalContext
    }

    deinit {
        mtmd_free(multimodalContext)
    }

    public func bitmap(images: [LLMInputImage]) throws(LLMError) -> MultimodalChunks {
        var bitmaps: [OpaquePointer?] = try images.map { image throws(LLMError) in
            let data = try llmInputImageToData(image)
            let (bytes, width, height) = imageDataToRGBBytes(imageData: data)!
            guard let bitmap = mtmd_bitmap_init(UInt32(width), UInt32(height), bytes) else {
                throw .failedToLoad(reason: "Failed to create bitmap")
            }
            return bitmap
        }
        defer {
            bitmaps.forEach(mtmd_bitmap_free)
        }

        let chunks = mtmd_input_chunks_init()!

        let textStorage = "    \(MTMD_DEFAULT_IMAGE_MARKER)    " // spaces for the workaround of tokenizer
        var text = textStorage.withCString {
            mtmd_input_text(text: $0, add_special: false, parse_special: true)
        }

        guard mtmd_tokenize(multimodalContext, chunks, &text, &bitmaps, bitmaps.count) == 0 else {
            throw .failedToLoad(reason: "Failed to tokenize bitmap")
        }

        return MultimodalChunks(chunks: chunks)
    }
}

public final class MultimodalChunks: @unchecked Sendable {
    package let chunks: OpaquePointer

    public init(chunks: OpaquePointer) {
        self.chunks = chunks
    }

    deinit {
        mtmd_input_chunks_free(chunks)
    }
}

public extension Context {
    func decode(bitmap: MultimodalChunks, with clip: ClipModel) throws(LLMError) {
        var newPosition: Int32 = 0
        mtmd_helper_eval_chunks(clip.multimodalContext,
                                context,
                                bitmap.chunks,
                                position,
                                0, // seq_id
                                Int32(parameter.batch),
                                true, // logits_last
                                &newPosition)
    }
}
