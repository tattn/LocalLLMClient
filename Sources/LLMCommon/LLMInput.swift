import Foundation

public struct LLMInput: Sendable {
    public init(
        prompt: String,
        parsesSpecial: Bool? = nil,
        attachments: [String: LLMAttachment] = [:]
    ) {
        self.prompt = prompt
        self.parsesSpecial = parsesSpecial
        self.attachments = attachments
    }

    public var prompt: String
    public var parsesSpecial: Bool?
    public var attachments: [String: LLMAttachment] = [:]
}

extension LLMInput: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.prompt = value
    }
}

public enum LLMAttachment: Sendable {
    case text(String)
    case image(any LLMEmbedding)
}

public protocol LLMEmbedding: Sendable {}
