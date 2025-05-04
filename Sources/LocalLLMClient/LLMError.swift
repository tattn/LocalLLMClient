public enum LLMError: Swift.Error {
    case failedToLoad(reason: String)
    case invalidParameter
    case decodingFailed
    case clipModelNotFound
    case visionUnsupported
}
