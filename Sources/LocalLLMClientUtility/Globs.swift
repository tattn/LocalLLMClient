/// A struct representing a collection of glob patterns used to filter files.
public struct Globs: Sendable, Equatable {
    public let rawValue: [String]

    /// Initializes a new set of glob patterns.
    ///
    /// - Parameter globs: An array of strings, where each string is a glob pattern (e.g., "*.json", "model.*.gguf").
    public init(_ globs: [String]) {
        self.rawValue = globs
    }

    /// Default glob patterns for MLX models, typically including "*.safetensors" and "*.json".
    public static let mlx = Globs(["*.safetensors", "*.json"])
}

extension Globs: ExpressibleByArrayLiteral {
    /// Initializes a new set of glob patterns from an array literal
    /// - Parameter elements: Array of strings representing glob patterns
    public init(arrayLiteral elements: String...) {
        self.init(elements)
    }
}
