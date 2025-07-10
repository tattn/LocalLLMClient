import Foundation

/// A chunk of content that can be streamed from an LLM response
/// This enum is designed to be extensible for future response types
public enum StreamingChunk: Sendable {
    /// Regular text content
    case text(String)
    /// A detected tool call
    case toolCall(LLMToolCall)
    
    /// Convenience property to get text content if available
    public var text: String? {
        if case .text(let content) = self {
            return content
        }
        return nil
    }
    
    /// Convenience property to get tool call if available
    public var toolCall: LLMToolCall? {
        if case .toolCall(let call) = self {
            return call
        }
        return nil
    }
}