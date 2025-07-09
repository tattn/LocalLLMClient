import Foundation

/// Handles the execution of tools based on tool calls from the LLM
package actor ToolExecutor {
    /// Available tools for execution
    private let tools: [AnyLLMTool]
    
    /// Tool lookup cache for performance
    private let toolLookup: [String: AnyLLMTool]
    
    /// Maximum number of concurrent tool executions
    private let maxConcurrency: Int
    
    /// Creates a new tool executor
    /// - Parameters:
    ///   - tools: The available tools
    ///   - maxConcurrency: Maximum number of tools to execute concurrently (default: 10)
    package init(tools: [AnyLLMTool], maxConcurrency: Int = 10) {
        self.tools = tools
        self.maxConcurrency = maxConcurrency
        
        // Build lookup table for O(1) tool access
        var lookup: [String: AnyLLMTool] = [:]
        for tool in tools {
            lookup[tool.name] = tool
        }
        self.toolLookup = lookup
    }
    
    /// Executes a single tool call
    /// - Parameter toolCall: The tool call to execute
    /// - Returns: The tool output and any error that occurred
    package func execute(_ toolCall: LLMToolCall) async -> Result<ToolOutput, Error> {
        guard let tool = toolLookup[toolCall.name] else {
            return .failure(ToolError.executionFailed(
                toolName: toolCall.name,
                underlyingError: LLMError.invalidParameter(reason: "Tool '\(toolCall.name)' not found")
            ))
        }
        
        do {
            let output = try await tool.call(argumentsJSON: toolCall.arguments)
            return .success(output)
        } catch {
            return .failure(error)
        }
    }
    
    /// Executes multiple tool calls concurrently
    /// - Parameter toolCalls: The tool calls to execute
    /// - Returns: Array of results matching the order of input tool calls
    package func executeBatch(_ toolCalls: [LLMToolCall]) async -> [Result<ToolOutput, Error>] {
        guard !toolCalls.isEmpty else { return [] }
        
        return await withTaskGroup(of: (Int, Result<ToolOutput, Error>).self) { group in
            var results = Array<Result<ToolOutput, Error>?>(repeating: nil, count: toolCalls.count)
            var pendingIndex = 0
            var runningTasks = 0
            
            // Start initial batch of tasks up to maxConcurrency
            while pendingIndex < toolCalls.count && runningTasks < maxConcurrency {
                let index = pendingIndex
                let toolCall = toolCalls[index]
                group.addTask {
                    let result = await self.execute(toolCall)
                    return (index, result)
                }
                pendingIndex += 1
                runningTasks += 1
            }
            
            // Process results and add new tasks as slots become available
            for await (completedIndex, result) in group {
                results[completedIndex] = result
                runningTasks -= 1
                
                // Add next task if available
                if pendingIndex < toolCalls.count {
                    let index = pendingIndex
                    let toolCall = toolCalls[index]
                    group.addTask {
                        let result = await self.execute(toolCall)
                        return (index, result)
                    }
                    pendingIndex += 1
                    runningTasks += 1
                }
            }
            
            return results.compactMap { $0 }
        }
    }
    
    /// Executes tool calls and returns formatted outputs for the LLM
    /// - Parameter toolCalls: The tool calls to execute
    /// - Returns: Array of tuples containing (toolCallId, formattedOutput) for successful executions
    /// - Throws: An aggregate error if any tool execution fails
    package func executeAndFormat(_ toolCalls: [LLMToolCall]) async throws -> [(String, String)] {
        let results = await executeBatch(toolCalls)
        
        var outputs: [(String, String)] = []
        var errors: [Error] = []
        
        for (index, result) in results.enumerated() {
            let toolCall = toolCalls[index]
            
            switch result {
            case .success(let output):
                let formattedOutput = formatToolOutput(output)
                outputs.append((toolCall.id, formattedOutput))
                
            case .failure(let error):
                errors.append(error)
            }
        }
        
        // If any errors occurred, throw an aggregate error
        if !errors.isEmpty {
            throw ToolExecutionError.multipleFailed(errors: errors)
        }
        
        return outputs
    }
    
    /// Formats a tool output for inclusion in LLM messages
    private func formatToolOutput(_ output: ToolOutput) -> String {
        do {
            // Try to serialize as JSON for structured output
            let jsonData = try JSONSerialization.data(withJSONObject: output.data, options: [.sortedKeys])
            let jsonString = String(decoding: jsonData, as: UTF8.self)
            return jsonString
        } catch {
            #if DEBUG
            print("[ToolExecutor] Failed to serialize tool output as JSON: \(error)")
            #endif
        }
        
        // Fallback to string representation
        return output.data
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")
    }
}

/// Errors that can occur during tool execution
package enum ToolExecutionError: LocalizedError {
    case multipleFailed(errors: [Error])
    
    package var errorDescription: String? {
        switch self {
        case .multipleFailed(let errors):
            let errorMessages = errors.map { $0.localizedDescription }.joined(separator: "; ")
            return "Multiple tool executions failed: \(errorMessages)"
        }
    }
}

// MARK: - Tool Validation

extension ToolExecutor {
    /// Validates that all required tools are available for the given tool calls
    /// - Parameter toolCalls: The tool calls to validate
    /// - Returns: Array of missing tool names, empty if all tools are available
    package func validateTools(for toolCalls: [LLMToolCall]) -> [String] {
        let requiredTools = Set(toolCalls.map { $0.name })
        let availableTools = Set(toolLookup.keys)
        return Array(requiredTools.subtracting(availableTools))
    }
    
    /// Checks if a specific tool is available
    /// - Parameter toolName: The name of the tool to check
    /// - Returns: True if the tool is available
    package func hasTool(named toolName: String) -> Bool {
        toolLookup[toolName] != nil
    }
    
    /// Gets the list of available tool names
    package var availableToolNames: [String] {
        Array(toolLookup.keys).sorted()
    }
}