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
        ///   - nGpuLayers: Number of model layers to offload to the GPU (Metal on Apple platforms). `-1` means "all layers". `0` runs everything on CPU. Default is `-1`.
        ///   - flashAttention: Enable Flash Attention. On Apple Silicon this is significantly faster and uses less memory. Default is `true`.
        ///   - kvCacheTypeK: Quantization type for the key half of the KV cache. Lower precision (`.q8_0`, `.q4_0`) reduces memory roughly proportionally, allowing larger context. Default is `.f16` (no quantization).
        ///   - kvCacheTypeV: Quantization type for the value half of the KV cache. Default is `.f16`.
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
            nGpuLayers: Int = -1,
            flashAttention: Bool = true,
            kvCacheTypeK: KVCacheType = .f16,
            kvCacheTypeV: KVCacheType = .f16,
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
            self.nGpuLayers = nGpuLayers
            self.flashAttention = flashAttention
            self.kvCacheTypeK = kvCacheTypeK
            self.kvCacheTypeV = kvCacheTypeV
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

        /// Number of model layers to offload to the GPU (Metal on Apple platforms).
        /// `-1` means "all layers" — typically the desired setting on Apple Silicon
        /// where the GPU has unified memory access. `0` forces CPU-only execution.
        public var nGpuLayers: Int
        /// Enable Flash Attention. On Apple Silicon (M-series, A-series) this is
        /// significantly faster and uses less memory. Set to `false` only for
        /// hardware that lacks support or for debugging.
        public var flashAttention: Bool
        /// Quantization type for the key half of the KV cache.
        public var kvCacheTypeK: KVCacheType
        /// Quantization type for the value half of the KV cache.
        public var kvCacheTypeV: KVCacheType

        /// Additional options for the Llama client.
        public var options: Options

        /// Default parameter settings.
        public static let `default` = Parameter()
    }

    /// KV cache quantization types. Lower precision reduces memory used by the
    /// KV cache, which scales linearly with `context` size. The quality cost
    /// is usually negligible at `.q8_0` and only modest at `.q4_0`.
    enum KVCacheType: String, Sendable, CaseIterable {
        /// Half precision (16-bit float). Default; no quantization.
        case f16
        /// 8-bit quantization. Roughly 50% memory of `.f16`, very low quality cost.
        case q8_0
        /// 4-bit quantization. Roughly 25% memory of `.f16`, modest quality cost.
        case q4_0
    }

    /// Defines additional, less commonly used options for the Llama client.
    struct Options: Sendable {
        /// Initializes a new set of options for the Llama client.
        ///
        /// - Parameters:
        ///   - responseFormat: Specifies the desired format for the model's response, such as JSON or a custom grammar. `nil` means no specific format is enforced. Default is `nil`.
        ///   - extraEOSTokens: A set of additional strings that, when encountered, will be treated as end-of-sequence tokens by the model. Default is an empty set.
        ///   - verbose: If `true`, enables verbose output for debugging purposes. Default is `false`.
        ///   - disableAutoPause: If `true`, disables automatic pausing when the app goes to background on iOS. Default is `false`.
        public init(
            responseFormat: ResponseFormat? = nil,
            extraEOSTokens: Set<String> = [],
            verbose: Bool = false,
            disableAutoPause: Bool = false
        ) {
            self.responseFormat = responseFormat
            self.extraEOSTokens = extraEOSTokens
            self.verbose = verbose
            self.disableAutoPause = disableAutoPause
        }

        /// Specifies the desired format for the model's response (e.g., JSON, custom grammar).
        public var responseFormat: ResponseFormat?
        /// Additional strings to be treated as end-of-sequence tokens.
        public var extraEOSTokens: Set<String>
        /// If `true`, enables verbose output for debugging purposes.
        public var verbose: Bool
        /// If `true`, disables automatic pausing when the app goes to background on iOS.
        public var disableAutoPause: Bool
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
