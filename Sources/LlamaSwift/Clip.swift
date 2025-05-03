import Foundation
import LocalLLMClient
@_exported import LlamaSwiftExperimentalC

public class ClipModel {
    package let clip: OpaquePointer

    public init(url: URL, verbose: Bool = false) throws(LLMError) {
        guard let clipContext = clip_model_load(url.path(), verbose ? 1 : 999) else {
            throw .failedToLoad
        }
        self.clip = clipContext
    }

    deinit {
        clip_free(clip)
    }

    public func embedded(imageData: Data, threads: Int = 4) throws(LLMError) -> ImageEmbed {
        guard let embed = imageData.withUnsafeBytes({ buffer in
            let bytes = buffer.bindMemory(to: UInt8.self).baseAddress
            return llava_image_embed_make_with_bytes(clip, Int32(threads), bytes, Int32(buffer.count))
        }) else {
            throw .failedToLoad
        }
        return ImageEmbed(embed: embed)
    }
}

public final class ImageEmbed: LLMEmbedding, @unchecked Sendable {
    package let embed: UnsafeMutablePointer<llava_image_embed>

    public init(embed: UnsafeMutablePointer<llava_image_embed>) {
        self.embed = embed
    }

    deinit {
        llava_image_embed_free(embed)
    }
}

public extension Context {
    func decode(imageEmbed embed: ImageEmbed, context decodeContext: DecodingContext) throws(LLMError) -> DecodingContext {
        var decodeContext = decodeContext
        guard llava_eval_image_embed(context, embed.embed, numberOfBatch, &decodeContext.cursor) else {
            throw .decodingFailed
        }
        return decodeContext
    }
}
