public extension LlamaClient {
    /// Defines the parameters for the Llama client and model.
    ///
    /// These parameters control various aspects of the text generation process,
    /// such as the context size, sampling methods, and penalty settings.
    struct Parameter: Sendable {
        /// Initializes a new set of parameters for the Llama client.
        ///
        /// - Parameters:
        ///   - context: The size of the context window in tokens. Default is `2048`.
        ///   - seed: The random seed for generation. `nil` means a random seed will be used. Default is `nil`.
        ///   - numberOfThreads: The number of threads to use for generation. `nil` means the optimal number of threads will be chosen. Default is `nil`.
        ///   - batch: The batch size for prompt processing. Default is `512`.
        ///   - temperature: Controls randomness in sampling. Lower values make the model more deterministic. Default is `0.8`.
        ///   - topK: Limits sampling to the K most likely tokens. Default is `40`.
        ///   - topP: Limits sampling to a cumulative probability. Default is `0.95`.
        ///   - typicalP: Limits sampling based on typical probability. Default is `1`.
        ///   - penaltyLastN: The number of recent tokens to consider for penalty. Default is `64`.
        ///   - penaltyRepeat: The penalty factor for repeating tokens. Default is `1.1`.
        ///   - options: Additional options for the Llama client.
        public init(
            context: Int = 2048,
            seed: Int? = nil,
            numberOfThreads: Int? = nil,
            batch: Int = 512,
            temperature: Float = 0.8,
            topK: Int = 40,
            topP: Float = 0.95,
            typicalP: Float = 1,
            penaltyLastN: Int = 64,
            penaltyRepeat: Float = 1.1,
            options: Options = .init()
        ) {
            self.context = context
            self.seed = seed
            self.numberOfThreads = numberOfThreads
            self.batch = batch
            self.temperature = temperature
            self.topK = topK
            self.topP = topP
            self.typicalP = typicalP
            self.penaltyLastN = penaltyLastN
            self.penaltyRepeat = penaltyRepeat
            self.options = options
        }
        
        /// The size of the context window in tokens.
        public var context: Int
        /// The random seed for generation. `nil` means a random seed will be used.
        public var seed: Int?
        /// The number of threads to use for generation. `nil` means the optimal number of threads will be chosen.
        public var numberOfThreads: Int?
        /// The batch size for prompt processing.
        public var batch: Int
        /// Controls randomness in sampling. Lower values make the model more deterministic.
        public var temperature: Float
        /// Limits sampling to the K most likely tokens.
        public var topK: Int
        /// Limits sampling to a cumulative probability.
        public var topP: Float
        /// Limits sampling based on typical probability.
        public var typicalP: Float
        /// The number of recent tokens to consider for penalty.
        public var penaltyLastN: Int
        /// The penalty factor for repeating tokens.
        public var penaltyRepeat: Float

        /// Additional options for the Llama client.
        public var options: Options

        /// Default parameter settings.
        public static let `default` = Parameter()
    }

    /// Defines additional, less commonly used options for the Llama client.
    struct Options: Sendable {
        /// Initializes a new set of options for the Llama client.
        ///
        /// - Parameters:
        ///   - responseFormat: Specifies the desired format for the model's response, such as JSON or a custom grammar. `nil` means no specific format is enforced. Default is `nil`.
        ///   - extraEOSTokens: A set of additional strings that, when encountered, will be treated as end-of-sequence tokens by the model. Default is an empty set.
        ///   - verbose: If `true`, enables verbose output for debugging purposes. Default is `false`.
        public init(
            responseFormat: ResponseFormat? = nil,
            extraEOSTokens: Set<String> = [],
            verbose: Bool = false
        ) {
            self.responseFormat = responseFormat
            self.extraEOSTokens = extraEOSTokens
            self.verbose = verbose
        }

        /// Specifies the desired format for the model's response (e.g., JSON, custom grammar).
        public var responseFormat: ResponseFormat?
        /// Additional strings to be treated as end-of-sequence tokens.
        public var extraEOSTokens: Set<String>
        /// If `true`, enables verbose output for debugging purposes.
        public var verbose: Bool
    }

    /// Specifies the desired format for the model's response.
    enum ResponseFormat: Sendable {
        /// Constrains the model's output to a specific grammar defined in GBNF (GGML BNF) format.
        /// - Parameters:
        ///   - gbnf: The grammar definition in GBNF format.
        ///   - root: The name of the root rule in the GBNF grammar. Defaults to "root".
        case grammar(gbnf: String, root: String = "root")
        /// Constrains the model's output to valid JSON format.
        case json
    }
}
