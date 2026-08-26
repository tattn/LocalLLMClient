import Foundation

/// Errors that can occur during tool execution
public enum ToolError: LocalizedError {
    case invalidArgumentEncoding(toolName: String, encoding: String.Encoding = .utf8)
    case argumentDecodingFailed(toolName: String, underlyingError: Error)
    case executionFailed(toolName: String, underlyingError: Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidArgumentEncoding(let toolName, let encoding):
            return "Failed to encode arguments for tool '\(toolName)' using \(encoding)"
        case .argumentDecodingFailed(let toolName, let error):
            return "Failed to decode arguments for tool '\(toolName)': \(error.localizedDescription)"
        case .executionFailed(let toolName, let error):
            return "Tool '\(toolName)' execution failed: \(error.localizedDescription)"
        }
    }
}

/// A type-erased wrapper for any LLMTool
public struct AnyLLMTool: Sendable {
    private let _name: String
    private let _description: String
    private let _argumentsSchema: [String: any Sendable]
    private let _call: @Sendable (String) async throws -> ToolOutput
    private let _tool: any LLMTool
    
    /// The name of the tool
    public var name: String { _name }
    
    /// The description of the tool
    public var description: String { _description }
    
    /// The JSON schema for the tool parameters
    public var argumentsSchema: [String: any Sendable] { _argumentsSchema }
    
    /// The underlying tool
    public var underlyingTool: any LLMTool { _tool }
    
    /// Creates a type-erased wrapper for an LLMTool
    /// - Parameter tool: The tool to wrap
    public init<T: LLMTool>(_ tool: T) {
        self._name = tool.name
        self._description = tool.description
        self._argumentsSchema = generateToolSchema(from: T.Arguments.argumentsSchema)
        self._tool = tool
        self._call = { argumentsJSON in
            guard let data = argumentsJSON.data(using: .utf8) else {
                throw ToolError.invalidArgumentEncoding(toolName: tool.name)
            }
            
            do {
                let arguments = try JSONDecoder().decode(T.Arguments.self, from: data)
                return try await tool.call(arguments: arguments)
            } catch let error as DecodingError {
                throw ToolError.argumentDecodingFailed(toolName: tool.name, underlyingError: error)
            } catch {
                throw ToolError.executionFailed(toolName: tool.name, underlyingError: error)
            }
        }
    }
    
    /// Creates a type-erased tool whose name, description and JSON schema are
    /// all supplied at runtime.
    ///
    /// The schema-from-a-static-type route above cannot serve a host whose tools
    /// come from a registry — an agent runtime discovers them while running, as
    /// data, so there is no Swift type to hang `argumentsSchema` on. Every stored
    /// field is already dynamic, so this is the same wrapper reached another way.
    ///
    /// - Parameters:
    ///   - name: The tool name the model will call.
    ///   - description: What the tool does.
    ///   - argumentsSchema: JSON Schema for the parameters, as a dictionary.
    ///   - call: Receives the raw arguments JSON the model produced.
    public init(
        name: String,
        description: String,
        argumentsSchema: [String: any Sendable],
        call: @escaping @Sendable (String) async throws -> ToolOutput
    ) {
        self._name = name
        self._description = description
        self._argumentsSchema = argumentsSchema
        self._tool = DynamicLLMTool(name: name, description: description)
        self._call = call
    }

    /// Executes the tool with JSON-encoded arguments
    /// - Parameter argumentsJSON: JSON string containing the arguments
    /// - Returns: The tool output
    /// - Throws: A `ToolError` if decoding or execution fails
    public func call(argumentsJSON: String) async throws -> ToolOutput {
        try await _call(argumentsJSON)
    }
    
    /// Executes the tool with a dictionary of arguments
    /// - Parameter arguments: Dictionary containing the arguments
    /// - Returns: The tool output
    /// - Throws: A `ToolError` if encoding, decoding or execution fails
    public func call(arguments: [String: Any]) async throws -> ToolOutput {
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: arguments)
        } catch {
            throw ToolError.argumentDecodingFailed(toolName: name, underlyingError: error)
        }
        
        let jsonString = String(decoding: jsonData, as: UTF8.self)
        
        return try await call(argumentsJSON: jsonString)
    }
}

// MARK: - Equatable & Hashable

extension AnyLLMTool: Equatable {
    public static func == (lhs: AnyLLMTool, rhs: AnyLLMTool) -> Bool {
        // Compare both name and description to ensure uniqueness
        lhs.name == rhs.name && lhs.description == rhs.description
    }
}

extension AnyLLMTool: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(description)
    }
}