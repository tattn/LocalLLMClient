public extension LlamaClient {
    struct Parameter: Sendable {
        public init(
            context: Int = 2048,
            numberOfThreads: Int? = nil,
            batch: Int = 512,
            temperature: Float = 0.9,
            topK: Int = 40,
            topP: Float = 0.9,
            typicalP: Float = 1,
            penaltyLastN: Int = 64,
            penaltyRepeat: Float = 1,
        ) {
            self.context = context
            self.numberOfThreads = numberOfThreads
            self.batch = batch
            self.temperature = temperature
            self.topK = topK
            self.topP = topP
            self.typicalP = typicalP
            self.penaltyLastN = penaltyLastN
            self.penaltyRepeat = penaltyRepeat
        }
        
        public var context: Int
        public var numberOfThreads: Int?
        public var batch: Int
        public var temperature: Float
        public var topK: Int
        public var topP: Float
        public var typicalP: Float
        public var penaltyLastN: Int
        public var penaltyRepeat: Float = 1
        
        public static let `default` = Parameter()
    }
}
