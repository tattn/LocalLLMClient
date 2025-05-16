/// Errors that can occur when interacting with the Local LLM Client.
public enum LLMError: Swift.Error {
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
}
