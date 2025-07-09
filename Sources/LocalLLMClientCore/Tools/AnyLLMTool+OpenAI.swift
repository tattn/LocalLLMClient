import Foundation

// MARK: - OpenAI Compatible JSON Conversion

extension AnyLLMTool {
    /// Converts the tool to a JSON representation compatible with OpenAI format.
    ///
    /// This method converts the tool definition to the OpenAI-compatible JSON format
    /// required by various LLM frameworks for tool calling functionality.
    ///
    /// ## Example Output
    /// ```json
    /// {
    ///   "type": "function",
    ///   "function": {
    ///     "name": "get_weather",
    ///     "description": "Get the current weather for a location",
    ///     "parameters": {
    ///       "type": "object",
    ///       "properties": {
    ///         "location": {
    ///           "type": "string",
    ///           "description": "The city and state"
    ///         }
    ///       },
    ///       "required": ["location"]
    ///     }
    ///   }
    /// }
    /// ```
    ///
    /// - Returns: A dictionary containing the tool definition in OpenAI format
    public func toOAICompatJSON() -> [String: any Sendable] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": argumentsSchema as [String: any Sendable]
            ] as [String: any Sendable]
        ]
    }
    
    /// Converts the tool to a JSON data representation compatible with OpenAI format.
    ///
    /// - Parameter options: Options for writing the JSON data
    /// - Returns: JSON data containing the tool definition in OpenAI format
    /// - Throws: An error if the JSON serialization fails
    public func toOAICompatJSONData(options: JSONSerialization.WritingOptions = .prettyPrinted) throws -> Data {
        try JSONSerialization.data(withJSONObject: toOAICompatJSON(), options: options)
    }
    
    /// Converts the tool to a JSON string representation compatible with OpenAI format.
    ///
    /// - Parameter options: Options for writing the JSON data
    /// - Returns: JSON string containing the tool definition in OpenAI format
    /// - Throws: An error if the JSON serialization fails or string encoding fails
    public func toOAICompatJSONString(options: JSONSerialization.WritingOptions = .prettyPrinted) throws -> String {
        let data = try toOAICompatJSONData(options: options)
        let string = String(decoding: data, as: UTF8.self)
        return string
    }
}

// MARK: - Batch Conversion

extension Collection where Element == AnyLLMTool {
    /// Converts a collection of tools to OpenAI-compatible JSON format
    ///
    /// - Returns: An array of dictionaries containing tool definitions in OpenAI format
    public func toOAICompatJSON() -> [[String: Any]] {
        self.map { $0.toOAICompatJSON() }
    }
    
    /// Converts a collection of tools to OpenAI-compatible JSON data
    ///
    /// - Parameter options: Options for writing the JSON data
    /// - Returns: JSON data containing the tool definitions in OpenAI format
    /// - Throws: An error if the JSON serialization fails
    public func toOAICompatJSONData(options: JSONSerialization.WritingOptions = .prettyPrinted) throws -> Data {
        try JSONSerialization.data(withJSONObject: toOAICompatJSON(), options: options)
    }
    
    /// Converts a collection of tools to OpenAI-compatible JSON string
    ///
    /// - Parameter options: Options for writing the JSON data
    /// - Returns: JSON string containing the tool definitions in OpenAI format
    /// - Throws: An error if the JSON serialization fails or string encoding fails
    public func toOAICompatJSONString(options: JSONSerialization.WritingOptions = .prettyPrinted) throws -> String {
        let data = try toOAICompatJSONData(options: options)
        let string = String(decoding: data, as: UTF8.self)
        return string
    }
}
