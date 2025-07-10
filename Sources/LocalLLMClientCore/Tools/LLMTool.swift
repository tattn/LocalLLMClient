import Foundation

/// A protocol for a tool that can be used by the LLM.
///
/// Tools allow the model to call functions that can be used to perform
/// actions like searching the web, making calculations, or retrieving information.
///
/// ## Example Implementation
/// ```swift
/// struct WeatherTool: LLMTool {
///     let name = "get_weather"
///     let description = "Get the current weather for a location"
///     
///     struct Arguments: Decodable, ToolSchemaGeneratable {
///         let location: String
///         let unit: String?
///         
///         static var argumentsSchema: LLMToolArgumentsSchema {
///             [
///                 "location": .string(description: "The city and state"),
///                 "unit": .enum(values: ["celsius", "fahrenheit"])
///             ]
///         }
///     }
///     
///     func call(arguments: Arguments) async throws -> ToolOutput {
///         // Implementation
///     }
/// }
/// ```
public protocol LLMTool<Arguments>: Sendable {
    /// The type representing the tool's arguments
    associatedtype Arguments: Decodable & ToolSchemaGeneratable

    /// The name of the tool.
    var name: String { get }

    /// A description of what the tool does.
    var description: String { get }

    /// Executes the tool with the provided arguments.
    ///
    /// - Parameter arguments: The arguments for the tool execution
    /// - Returns: A `ToolOutput` containing structured data as a dictionary
    /// - Throws: An error if the tool execution fails
    func call(arguments: Arguments) async throws -> ToolOutput
}