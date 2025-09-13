import Foundation

/// Errors that can occur when interacting with the Local LLM Client.
public enum LLMError: LocalizedError {
    /// Indicates that the model failed to load.
    /// - Parameter reason: A description of why the model loading failed.
    case failedToLoad(reason: String)
    
    /// Indicates that an invalid parameter was provided to the LLM.
    /// - Parameter reason: A description of the invalid parameter.
    case invalidParameter(reason: String)

    /// Indicates that the LLM response could not be decoded.
    case failedToDecode(reason: String)

    /// Indicates that vision features are not supported by the current model or configuration.
    case visionUnsupported

    /// Indicates that the operation is not supported on the situation.
    case unsupportedOperation(reason: String)

    public var errorDescription: String? {
        switch self {
        case .failedToLoad(let reason):
            return "Failed to load model: \(reason)"
        case .invalidParameter(let reason):
            return "Invalid parameter: \(reason)"
        case .failedToDecode(let reason):
            return "Failed to decode response: \(reason)"
        case .visionUnsupported:
            return "Vision features are not supported by this model or configuration."
        case .unsupportedOperation(let reason):
            return "Unsupported operation: \(reason)"
        }
    }
}
