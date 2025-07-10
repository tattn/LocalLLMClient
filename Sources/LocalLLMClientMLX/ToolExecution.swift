import Foundation
import LocalLLMClientCore

/// Common tool execution logic
struct ToolExecution {
    /// Executes a tool with the given tool call
    ///
    /// - Parameters:
    ///   - tool: The tool to execute
    ///   - toolCall: The tool call containing arguments
    /// - Returns: The ToolOutput from the tool execution
    /// - Throws: An error if tool execution fails
    static func execute<Tool: LLMTool>(_ tool: Tool, with toolCall: LLMToolCall) async throws -> ToolOutput {
        // Convert the arguments string to Data
        guard let data = toolCall.arguments.data(using: .utf8) else {
            throw LLMError.invalidParameter(reason: "Invalid tool call arguments encoding for tool: \(toolCall.name)")
        }

        let decoder = JSONDecoder()
        let arguments = try decoder.decode(Tool.Arguments.self, from: data)
        return try await tool.call(arguments: arguments)
    }
    
    /// Finds a tool by name from the available tools
    ///
    /// - Parameters:
    ///   - name: The name of the tool to find
    ///   - tools: Available tools
    /// - Returns: The tool if found
    /// - Throws: An error if the tool is not found
    static func findTool(named name: String, in tools: [any LLMTool]) throws -> any LLMTool {
        guard let tool = tools.first(where: { $0.name == name }) else {
            throw LLMError.invalidParameter(reason: "Tool not found for call: \(name)")
        }
        return tool
    }
}