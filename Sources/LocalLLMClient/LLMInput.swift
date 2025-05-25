import Foundation

/// A structure representing various types of inputs for LLMs.
///
/// `LLMInput` encapsulates different formats of input data that can be provided to a language model:
/// - Plain text input
/// - Custom chat template format
/// - Chat messages with defined roles (system, user, assistant)
///
/// Example usage:
/// ```swift
/// // Plain text input
/// let plainInput = LLMInput.plain("Hello, how can I help you?")
///
/// // Chat template input
/// let templateInput = LLMInput.chatTemplate([
///     .init(value: ["role": "user", "content": "Hello"])
/// ])
///
/// // Chat messages input
/// let chatInput = LLMInput.chat([
///     .system("You are a helpful assistant"),
///     .user("Tell me about Swift")
/// ])
/// ```
public struct LLMInput: Sendable {
    /// Initializes an input with the specified value.
    ///
    /// - Parameter value: The input value
    public init(_ value: Input) {
        self.value = value
    }

    /// Creates a plain text input.
    ///
    /// - Parameter value: The text string to use as input.
    /// - Returns: An `LLMInput` instance with plain text input.
    public static func plain(_ value: String) -> LLMInput {
        .init(.plain(value))
    }

    /// Creates a custom chat template input.
    ///
    /// - Parameter messages: An array of chat template messages.
    /// - Returns: An `LLMInput` instance with chat template input.
    public static func chatTemplate(_ messages: [ChatTemplateMessage]) -> LLMInput {
        .init(.chatTemplate(messages))
    }

    /// Creates a chat input with role-based messages.
    ///
    /// - Parameter messages: An array of messages with defined roles.
    /// - Returns: An `LLMInput` instance with chat messages input.
    public static func chat(_ messages: [Message]) -> LLMInput {
        .init(.chat(messages))
    }

    /// The underlying input value.
    public var value: Input

    /// Enumeration representing the different types of inputs that can be provided to a language model.
    public enum Input: Sendable {
        /// Plain text input, e.g., "hello"
        case plain(String)

        /// Chat template input format with structured messages.
        /// Example: [.init(value: ["role": "user", "content": "hello", "type": "text"])]
        case chatTemplate(_ messages: [ChatTemplateMessage])

        /// Role-based chat messages.
        /// Example: [.init(role: .user, content: "hello")]
        case chat([Message])
    }
}

/// Enables creating an `LLMInput` directly from a string literal.
extension LLMInput: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.value = .plain(value)
    }
}

/// Represents different types of attachments that can be included with messages.
public enum LLMAttachment: @unchecked Sendable, Hashable {
    /// An image attachment.
    case image(LLMInputImage)
}

public extension LLMInput {
    /// A structure representing a message in chat template format.
    ///
    /// Chat template messages are structured as key-value pairs that can be used
    /// by language models that expect input in a specific format.
    struct ChatTemplateMessage: Sendable {
        /// Initializes a chat template message.
        ///
        /// - Parameters:
        ///   - value: A dictionary of key-value pairs representing the message structure.
        ///   - attachments: Optional attachments to include with the message.
        public init(
            value: [String: any Sendable],
            attachments: [LLMAttachment] = []
        ) {
            self.value = value
            self.attachments = attachments
        }

        /// The key-value pairs representing the message structure.
        public var value: [String: any Sendable]
        
        /// Attachments associated with this message.
        public var attachments: [LLMAttachment]
    }

    /// A structure representing a role-based message in a conversation.
    ///
    /// Each message has a role (system, user, assistant, or custom), content text,
    /// and optional attachments such as images.
    struct Message: Sendable, Hashable {
        /// Initializes a message with the specified role and content.
        ///
        /// - Parameters:
        ///   - role: The role of the message sender.
        ///   - content: The text content of the message.
        ///   - attachments: Optional attachments to include with the message.
        public init(
            role: Role,
            content: String,
            attachments: [LLMAttachment] = []
        ) {
            self.role = role
            self.content = content
            self.attachments = attachments
        }

        /// Creates a system message.
        ///
        /// System messages provide instructions or context to the language model.
        ///
        /// - Parameter content: The text content of the system message.
        /// - Returns: A new `Message` instance with system role.
        public static func system(_ content: String) -> Message {
            .init(role: .system, content: content)
        }

        /// Creates a user message.
        ///
        /// User messages represent input from the end-user.
        ///
        /// - Parameters:
        ///   - content: The text content of the user message.
        ///   - attachments: Optional attachments to include with the message.
        /// - Returns: A new `Message` instance with user role.
        public static func user(_ content: String, attachments: [LLMAttachment] = []) -> Message {
            .init(role: .user, content: content, attachments: attachments)
        }

        /// Creates an assistant message.
        ///
        /// Assistant messages represent responses from the language model.
        ///
        /// - Parameters:
        ///   - content: The text content of the assistant message.
        ///   - attachments: Optional attachments to include with the message.
        /// - Returns: A new `Message` instance with assistant role.
        public static func assistant(_ content: String, attachments: [LLMAttachment] = []) -> Message {
            .init(role: .assistant, content: content, attachments: attachments)
        }

        /// The role of the message sender.
        public var role: Role
        
        /// The text content of the message.
        public var content: String
        
        /// Attachments associated with this message.
        public var attachments: [LLMAttachment]

        /// Enumeration representing the role of a message sender in a conversation.
        public enum Role: Sendable, Hashable {
            /// System role, typically used for instructions or context.
            case system
            
            /// User role, representing end-user input.
            case user
            
            /// Assistant role, representing language model responses.
            case assistant
            
            /// Custom role with a specified name.
            case custom(String)

            /// The string representation of the role.
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

#if os(macOS)
import class CoreImage.CIImage
@preconcurrency import class AppKit.NSImage
@preconcurrency import class AppKit.NSBitmapImageRep
/// On macOS, represents an image that can be used as input to a language model.
public typealias LLMInputImage = NSImage

/// Converts an image to PNG data.
///
/// - Parameter image: The image to convert.
/// - Returns: PNG data representation of the image.
/// - Throws: `LLMError.failedToLoad` if the conversion fails.
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

/// Converts an image to a CIImage.
///
/// - Parameter image: The image to convert.
/// - Returns: CIImage representation of the image.
/// - Throws: `LLMError.failedToLoad` if the conversion fails.
package func llmInputImageToCIImage(_ image: LLMInputImage) throws(LLMError) -> CIImage {
    guard let imageData = image.tiffRepresentation, let ciImage = CIImage(data: imageData) else {
        throw LLMError.failedToLoad(reason: "Failed to load image")
    }
    return ciImage
}
#elseif os(iOS)
import class CoreImage.CIImage
@preconcurrency import class UIKit.UIImage
/// On iOS, represents an image that can be used as input to a language model.
public typealias LLMInputImage = UIImage

/// Converts an image to PNG data.
///
/// - Parameter image: The image to convert.
/// - Returns: PNG data representation of the image.
/// - Throws: `LLMError.failedToLoad` if the conversion fails.
package func llmInputImageToData(_ image: LLMInputImage) throws(LLMError) -> Data {
    guard let data = image.pngData() else {
        throw LLMError.failedToLoad(reason: "Failed to convert image to PNG")
    }
    return data
}

/// Converts an image to a CIImage.
///
/// - Parameter image: The image to convert.
/// - Returns: CIImage representation of the image.
/// - Throws: `LLMError.failedToLoad` if the conversion fails.
package func llmInputImageToCIImage(_ image: LLMInputImage) throws(LLMError) -> CIImage {
    guard let ciImage = CIImage(image: image) else {
        throw LLMError.failedToLoad(reason: "Failed to load image")
    }
    return ciImage
}
#else
public typealias LLMInputImage = Data

/// Converts an image to data.
///
/// - Parameter image: The image to convert.
/// - Returns: Data representation of the image.
/// - Throws: `LLMError.failedToLoad` if the conversion fails.
package func llmInputImageToData(_ image: LLMInputImage) throws(LLMError) -> Data {
    image
}
#endif
