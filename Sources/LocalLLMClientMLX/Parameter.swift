import MLXLMCommon

public extension MLXClient {
    struct Parameter: Sendable {
        public init(
            maxTokens: Int? = nil,
            temperature: Float = 0.6,
            topP: Float = 1.0,
            repetitionPenalty: Float? = nil,
            repetitionContextSize: Int = 20
        ) {
            parameters = .init(
                maxTokens: maxTokens,
                temperature: temperature,
                topP: topP,
                repetitionPenalty: repetitionPenalty,
                repetitionContextSize: repetitionContextSize
            )
        }

        public let parameters: GenerateParameters

        public static let `default` = Parameter()
    }
}
