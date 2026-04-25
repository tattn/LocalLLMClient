/// A struct representing a collection of glob patterns used to filter files.
public struct Globs: Sendable, Equatable {
    public var rawValue: [String]

    /// Initializes a new set of glob patterns.
    ///
    /// - Parameter globs: An array of strings, where each string is a glob pattern (e.g., "*.json", "model.*.gguf").
    public init(_ globs: [String]) {
        self.rawValue = globs
    }

    /// Default glob patterns for MLX models, covering weights, config JSON and
    /// the chat template (newer models such as Gemma 4 ship it as a separate
    /// `chat_template.jinja` file instead of inlining it in `tokenizer_config.json`).
    public static let mlx = Globs(["*.safetensors", "*.json", "*.jinja"])

    /// Appends a new glob pattern to the set.
    /// - Parameter glob: A string representing a glob pattern to be added.
    public mutating func append(_ glob: String) {
        rawValue.append(glob)
    }
}

extension Globs: ExpressibleByArrayLiteral {
    /// Initializes a new set of glob patterns from an array literal
    /// - Parameter elements: Array of strings representing glob patterns
    public init(arrayLiteral elements: String...) {
        self.init(elements)
    }
}
