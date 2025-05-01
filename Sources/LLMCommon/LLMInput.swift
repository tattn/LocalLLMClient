public struct LLMInput {
    public init(prompt: String) {
        self.prompt = prompt
    }

    public var prompt: String
}

extension LLMInput: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.prompt = value
    }
}
