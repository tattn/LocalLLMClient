import LocalLLMClientCore
import Foundation

/// Represents a chunk of content in a message
enum MessageChunk: Equatable, Hashable {
    case text(String)
    case image([LLMInputImage])
    case video([LLMInputImage]) // Placeholder for future video support
}
