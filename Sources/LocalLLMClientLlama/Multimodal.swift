import Foundation
import LocalLLMClientCore
@_exported import LocalLLMClientLlamaC

public class MultimodalContext: @unchecked Sendable {
    package let multimodalContext: OpaquePointer
    package let verbose: Bool

    package init(url: URL, context: Context, parameter: LlamaClient.Parameter) throws(LLMError) {
        var mparams = mtmd_context_params_default()
        mparams.use_gpu = true
        mparams.print_timings = parameter.options.verbose
        if let numberOfThreads = parameter.numberOfThreads {
            mparams.n_threads = Int32(numberOfThreads)
        }
        mparams.verbosity = parameter.options.verbose ? GGML_LOG_LEVEL_DEBUG : GGML_LOG_LEVEL_CONT;
        guard let multimodalContext = mtmd_init_from_file(url.path(), context.model.model, mparams) else {
            throw .failedToLoad(reason: "Failed to load the mmproj file")
        }
        self.multimodalContext = multimodalContext
        self.verbose = parameter.options.verbose
    }

    deinit {
        mtmd_free(multimodalContext)
    }

    package func chunks(images: [LLMInputImage]) throws(LLMError) -> MultimodalChunks {
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

package final class MultimodalChunks: @unchecked Sendable {
    package let chunks: OpaquePointer

    public init(chunks: OpaquePointer) {
        self.chunks = chunks
    }

    deinit {
        mtmd_input_chunks_free(chunks)
    }
}

package extension Context {
    func decode(bitmap: MultimodalChunks, with multimodal: MultimodalContext) throws(LLMError) {
        var newPosition: Int32 = 0
        let chunk = mtmd_input_chunks_get(bitmap.chunks, 1) // 1: <space><img><space>

        let imageTokens = mtmd_input_chunk_get_tokens_image(chunk)

        if multimodal.verbose {
            llamaLog(level: .debug, message: "encoding image or slice...\n")
        }

        guard mtmd_encode(multimodal.multimodalContext, imageTokens) == 0 else {
            throw .failedToDecode(reason: "Failed to encode image")
        }

        let embd = mtmd_get_output_embd(multimodal.multimodalContext);
        guard mtmd_helper_decode_image_chunk(
            multimodal.multimodalContext,
            context,
            chunk,
            embd,
            position,
            0, // seq_id
            Int32(parameter.batch),
            &newPosition) == 0 else {
            throw .failedToDecode(reason: "Failed to decode image")
        }
    }
}
