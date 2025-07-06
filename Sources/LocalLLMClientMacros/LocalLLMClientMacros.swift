import Foundation
import LocalLLMClientCore

/// A macro that automatically generates a nested ToolSchema struct from tool arguments.
/// 
/// This macro analyzes the properties of the struct and generates a corresponding
/// ToolSchema struct with ToolArgument instances for each property marked with @ToolArgument.
///
/// Example:
/// ```swift
/// @ToolArguments
/// struct Arguments: Decodable {
///     @ToolArgument("The city and state, e.g. San Francisco, CA")
///     var location: String
///     @ToolArgument("Temperature unit", enum: ["celsius", "fahrenheit"])
///     let unit: String?
/// }
/// ```
/// 
/// This will generate:
/// ```swift
/// static var argumentsSchema: LLMToolArgumentsSchema {
///     [
///         "location": .string(description: "The city and state, e.g. San Francisco, CA"),
///         "unit": .enum(values: ["celsius", "fahrenheit"], description: "Temperature unit")
///     ]
/// }
/// ```
@attached(member, names: named(argumentsSchema))
@attached(extension, conformances: Decodable, ToolSchemaGeneratable, ToolArgumentObject, names: arbitrary)
public macro ToolArguments() = #externalMacro(module: "LocalLLMClientMacrosPlugin", type: "ToolArgumentsMacro")

/// A property wrapper macro that marks a property as a tool argument.
///
/// This macro is used with `@ToolArguments` to indicate which properties
/// should be included in the generated ToolSchema.
///
/// - Parameters:
///   - description: A description of the argument
///   - enum: Optional array of allowed values (can be strings or integers)
///   - format: Optional format specifier (e.g., "byte" for base64 encoded data)
///
/// Example:
/// ```swift
/// @ToolArgument("The temperature value")
/// var temperature: Double
/// 
/// @ToolArgument("Status", enum: ["active", "inactive"])
/// var status: String
/// 
/// @ToolArgument("Priority level", enum: [1, 2, 3])
/// var priority: Int
/// ```
@attached(peer)
public macro ToolArgument(
    _ description: String,
    enum: [any Sendable]? = nil,
    format: String? = nil
) = #externalMacro(module: "LocalLLMClientMacrosPlugin", type: "ToolArgumentMacro")

/// A macro that automatically makes an enum conform to Decodable, ToolArgumentType, and CaseIterable.
///
/// This macro is useful for enums that are used as tool arguments, automatically
/// providing the necessary protocol conformances.
///
/// Example:
/// ```swift
/// @ToolArgumentEnum
/// enum Status: String {
///     case active
///     case inactive
///     case pending
/// }
/// ```
///
/// This will generate:
/// ```swift
/// extension Status: Decodable, ToolArgumentType, CaseIterable {}
/// ```
@attached(extension, conformances: Decodable, ToolArgumentType, CaseIterable, names: arbitrary)
public macro ToolArgumentEnum() = #externalMacro(module: "LocalLLMClientMacrosPlugin", type: "ToolArgumentEnumMacro")

/// A macro that automatically adds LLMTool protocol conformance to a struct and generates a name property.
///
/// This macro generates an extension that conforms the struct to the `LLMTool` protocol,
/// and adds a `name` property with the provided string value.
///
/// - Parameter name: The name of the tool
///
/// Example:
/// ```swift
/// @Tool("get_weather")
/// struct WeatherTool {
///     let description = "Get the current weather"
///     
///     struct Arguments: Decodable, ToolSchemaGeneratable {
///         let location: String
///         static var argumentsSchema: LLMToolArgumentsSchema {
///             ["location": .string(description: "The city and state")]
///         }
///     }
///     
///     func call(arguments: Arguments) async throws -> ToolOutput {
///         // Implementation
///     }
/// }
/// ```
///
/// This will generate:
/// ```swift
/// extension WeatherTool: LLMTool {}
/// ```
/// And add:
/// ```swift
/// let name = "get_weather"
/// ```
@attached(extension, conformances: LLMTool)
@attached(member, names: named(name))
public macro Tool(_ name: String) = #externalMacro(module: "LocalLLMClientMacrosPlugin", type: "ToolMacro")
