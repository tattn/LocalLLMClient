import Foundation
import LLMCommon
@_exported import LlamaSwift
@_exported import LlamaSwiftExperimentalC

public class ClipModel {
    package let clipContext: OpaquePointer

    public init(url: URL) throws(LLMError) {
        guard let clipContext = clip_model_load(url.path(), 1) else {
            throw .failedToLoad
        }
        self.clipContext = clipContext
    }

    deinit {
        clip_free(clipContext)
    }

    public func embedded(imageURL: URL, threads: Int = 4) throws(LLMError) -> ImageEmbed {
        guard let embed = llava_image_embed_make_with_filename(clipContext, Int32(threads), imageURL.path()) else {
            throw .failedToLoad
        }
        return ImageEmbed(embed: embed)
    }
}

public class ImageEmbed {
    package let embed: UnsafeMutablePointer<llava_image_embed>

    public init(embed: UnsafeMutablePointer<llava_image_embed>) {
        self.embed = embed
    }

    deinit {
        llava_image_embed_free(embed)
    }
}

public extension Context {
    func decode(imageEmbed embed: ImageEmbed, cursor: Int32) throws(LLMError) -> Int32 {
        var cursor = cursor
        guard llava_eval_image_embed(context, embed.embed, numberOfBatch, &cursor) else {
            throw .decodingFailed
        }
        return cursor
    }
}
