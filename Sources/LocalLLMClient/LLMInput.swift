import Foundation

public struct LLMInput: Sendable {
    public init(
        _ value: Input,
        parsesSpecial: Bool? = nil,
        attachments: [LLMAttachment] = []
    ) {
        self.value = value
        self.parsesSpecial = parsesSpecial
        self.attachments = attachments
    }

    public var value: Input
    public var parsesSpecial: Bool?
    public var attachments: [LLMAttachment] = []

    public enum Input: Sendable {
        /// e.g.) "hello"
        case plain(String)

        /// e.g.) [["role": "user", "content": "hello", "type": "text"]]
        case chatTemplate(_ messages: [[String: any Sendable]])

        /// e.g.) [Message(role: .user, content: "hello")]
        case chat([Message])
    }
}

extension LLMInput: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.value = .plain(value)
    }
}

public enum LLMAttachment: @unchecked Sendable {
    case image(LLMInputImage)
}

public extension LLMInput.Input {
    struct Message: Sendable {
        public init(
            role: Role,
            content: String
        ) {
            self.role = role
            self.content = content
        }

        public static func system(_ content: String) -> Message {
            .init(role: .system, content: content)
        }

        public static func user(_ content: String) -> Message {
            .init(role: .user, content: content)
        }

        public static func assistant(_ content: String) -> Message {
            .init(role: .assistant, content: content)
        }

        public var role: Role
        public var content: String
        // TODO: Attachments

        public enum Role: Sendable {
            case system
            case user
            case assistant
            case custom(String)

            public var rawValue: String {
                switch self {
                case .system: "system"
                case .user: "user"
                case .assistant: "assistant"
                case .custom(let value): value
                }
            }
        }
    }
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
