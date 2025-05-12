import Foundation

public struct LLMInput: Sendable {
    public init(_ value: Input) {
        self.value = value
    }

    public static func plain(_ value: String) -> LLMInput {
        .init(.plain(value))
    }

    public static func chatTemplate(_ messages: [ChatTemplateMessage]) -> LLMInput {
        .init(.chatTemplate(messages))
    }

    public static func chat(_ messages: [Message]) -> LLMInput {
        .init(.chat(messages))
    }

    public var value: Input

    public enum Input: Sendable {
        /// e.g.) "hello"
        case plain(String)

        /// e.g.) [ChatTemplateMessage(value: ["role": "user", "content": "hello", "type": "text"])]
        case chatTemplate(_ messages: [ChatTemplateMessage])

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

public extension LLMInput {
    struct ChatTemplateMessage: Sendable {
        public init(
            value: [String: any Sendable],
            attachments: [LLMAttachment] = []
        ) {
            self.value = value
            self.attachments = attachments
        }

        public var value: [String: any Sendable]
        public var attachments: [LLMAttachment]
    }

    struct Message: Sendable {
        public init(
            role: Role,
            content: String,
            attachments: [LLMAttachment] = []
        ) {
            self.role = role
            self.content = content
            self.attachments = attachments
        }

        public static func system(_ content: String) -> Message {
            .init(role: .system, content: content)
        }

        public static func user(_ content: String, attachments: [LLMAttachment] = []) -> Message {
            .init(role: .user, content: content, attachments: attachments)
        }

        public static func assistant(_ content: String, attachments: [LLMAttachment] = []) -> Message {
            .init(role: .assistant, content: content, attachments: attachments)
        }

        public var role: Role
        public var content: String
        public var attachments: [LLMAttachment]

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
