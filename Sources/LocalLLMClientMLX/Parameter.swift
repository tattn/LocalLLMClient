import MLXLMCommon

public extension MLXClient {
    /// Defines the parameters for the MLX client and model.
    ///
    /// These parameters control various aspects of the text generation process,
    /// such as token limits, sampling methods, and repetition penalties,
    /// largely by configuring the underlying `MLXLMCommon.GenerateParameters`.
    struct Parameter: Sendable {
        /// Initializes a new set of parameters for the MLX client.
        ///
        /// - Parameters:
        ///   - maxTokens: The maximum number of tokens to generate. If `nil`, generation continues until an end-of-sequence token is produced. Default is `nil`.
        ///   - temperature: Controls the randomness of the generated text. Higher values (e.g., 0.8) make the output more random, while lower values (e.g., 0.2) make it more focused. Default is `0.6`.
        ///   - topP: Restricts token selection to a cumulative probability distribution. Only tokens whose cumulative probability is less than or equal to `topP` are considered. Default is `1.0`.
        ///   - repetitionPenalty: The penalty applied to repeated tokens. A value of `nil` or `1.0` means no penalty. Higher values discourage repetition. Default is `nil`.
        ///   - repetitionContextSize: The number of recent tokens to consider for the repetition penalty. Default is `20`.
        ///   - options: Additional, less commonly used options for the MLX client.
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

        /// The core generation parameters passed to the `MLXLMCommon` framework.
        public var parameters: GenerateParameters
        /// Additional, less commonly used options for the MLX client.
        public var options: Options

        /// Provides a default set of parameters.
        public static let `default` = Parameter()
    }

    /// Defines additional, less commonly used options for the MLX client.
    struct Options: Sendable {
        /// Initializes a new set of options for the MLX client.
        ///
        /// - Parameters:
        ///   - extraEOSTokens: A set of additional strings that, when encountered, will be treated as end-of-sequence tokens by the model. Default is an empty set.
        public init(
            extraEOSTokens: Set<String> = []
        ) {
            self.extraEOSTokens = extraEOSTokens
        }

        /// Additional strings to be treated as end-of-sequence tokens by the model.
        public var extraEOSTokens: Set<String>
    }
}
