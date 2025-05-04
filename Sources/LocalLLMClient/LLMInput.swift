import Foundation

public struct LLMInput: Sendable {
    public init(
        prompt: String,
        parsesSpecial: Bool? = nil,
        attachments: [LLMAttachment] = []
    ) {
        self.prompt = prompt
        self.parsesSpecial = parsesSpecial
        self.attachments = attachments
    }

    public var prompt: String
    public var parsesSpecial: Bool?
    public var attachments: [LLMAttachment] = []
}

extension LLMInput: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.prompt = value
    }
}

public enum LLMAttachment: @unchecked Sendable {
    case image(LLMInputImage)
}

import class CoreImage.CIImage
#if os(macOS)
@preconcurrency import class AppKit.NSImage
@preconcurrency import class AppKit.NSBitmapImageRep
public typealias LLMInputImage = NSImage
package func llmInputImageToData(_ image: LLMInputImage) throws(LLMError) -> Data {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { throw LLMError.failedToLoad(reason: "Failed to load image") }
    let imageRep = NSBitmapImageRep(cgImage: cgImage)
    imageRep.size = image.size
    guard let result = imageRep.representation(using: .png, properties: [:]) else {
        throw LLMError.failedToLoad(reason: "Failed to convert image to PNG")
    }
    return result
}
package func llmInputImageToCIImage(_ image: LLMInputImage) throws(LLMError) -> CIImage {
    guard let imageData = image.tiffRepresentation, let ciImage = CIImage(data: imageData) else {
        throw LLMError.failedToLoad(reason: "Failed to load image")
    }
    return ciImage
}
#else
@preconcurrency import class UIKit.UIImage
public typealias LLMInputImage = UIImage
package func llmInputImageToData(_ image: LLMInputImage) -> Data {
    guard let data = image.pngData() else {
        fatalError("Failed to convert image to PNG")
    }
    return data
}
package func llmInputImageToCIImage(_ image: LLMInputImage) throws(LLMError) -> CIImage {
    guard let ciImage = CIImage(image: image) else {
        throw LLMError.failedToLoad(reason: "Failed to load image")
    }
    return ciImage
}
#endif
