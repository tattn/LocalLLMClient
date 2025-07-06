import Foundation

/// The output type for tool execution.
///
/// ## Overview
/// `ToolOutput` provides a way to return structured data from tool executions.
///
/// ## Example
/// ```swift
/// func call(arguments: Arguments) async throws -> ToolOutput {
///     return ToolOutput([
///         "temperature": 72,
///         "condition": "sunny",
///         "humidity": 45,
///         "forecast": ["Monday": "rainy", "Tuesday": "sunny"]
///     ])
/// }
/// ```
public struct ToolOutput: Sendable {
    /// The structured data returned by the tool.
    public let data: [String: any Sendable]
    
    /// Creates a tool output with structured data.
    /// - Parameter data: A dictionary containing the structured output with various types.
    public init(data: [String: any Sendable]) {
        self.data = data
    }
    
    /// Convenience initializer using dictionary literal
    /// - Parameter data: A dictionary containing the structured output
    public init(_ data: [String: any Sendable]) {
        self.data = data
    }
}