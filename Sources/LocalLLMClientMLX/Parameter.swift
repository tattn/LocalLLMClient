import MLXLMCommon

public extension MLXClient {
    struct Parameter: Sendable {
        public init(
            maxTokens: Int? = nil,
            temperature: Float = 0.6,
            topP: Float = 1.0,
            repetitionPenalty: Float? = nil,
            repetitionContextSize: Int = 20,
            options: Options = .init(),
        ) {
            parameters = .init(
                maxTokens: maxTokens,
                temperature: temperature,
                topP: topP,
                repetitionPenalty: repetitionPenalty,
                repetitionContextSize: repetitionContextSize
            )
            self.options = options
        }

        public var parameters: GenerateParameters
        public var options: Options

        public static let `default` = Parameter()
    }

    struct Options: Sendable {
        public init(
            extraEOSTokens: Set<String> = []
        ) {
            self.extraEOSTokens = extraEOSTokens
        }

        public var extraEOSTokens: Set<String>
    }
}
