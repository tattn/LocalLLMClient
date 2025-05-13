import Foundation
import LocalLLMClient
@_exported import LocalLLMClientLlamaC

public class ClipModel {
    package let clip: OpaquePointer

    public init(url: URL, verbose: Bool = false) throws(LLMError) {
        guard let clip = clip_init(url.path(), .init(use_gpu: true, verbosity: .init(verbose ? 1 : 999))) else {
            throw .failedToLoad(reason: "Failed to load clip model")
        }
        self.clip = clip
    }

    deinit {
        clip_free(clip)
    }

    public func embedded(image: LLMInputImage, threads: Int = 4) throws(LLMError) -> ImageEmbed {
        guard let embed = try llmInputImageToData(image).withUnsafeBytes({ buffer in
            let bytes = buffer.bindMemory(to: UInt8.self).baseAddress
            return llava_image_embed_make_with_bytes(clip, Int32(threads), bytes, Int32(buffer.count))
        }) else {
            throw .failedToLoad(reason: "Failed to create image embed")
        }
        return ImageEmbed(embed: embed)
    }
}

public final class ImageEmbed: @unchecked Sendable {
    package let embed: UnsafeMutablePointer<llava_image_embed>

    public init(embed: UnsafeMutablePointer<llava_image_embed>) {
        self.embed = embed
    }

    deinit {
        llava_image_embed_free(embed)
    }
}

public extension Context {
    func decode(imageEmbed embed: ImageEmbed) throws(LLMError) {
        var position = position
        guard llava_eval_image_embed(context, embed.embed, numberOfBatch, &position) else {
            throw .decodingFailed
        }
    }
}
