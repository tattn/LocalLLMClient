import Foundation
import LocalLLMClientCore
import MLX
import MLXLMCommon

/// Extension to MLXClient to add tool calling capabilities
extension MLXClient: LLMToolCallable {

    /// Generates text from the input and parses it for tool calls
    ///
    /// - Parameter input: The input to process
    /// - Returns: Generated content including text and any tool calls
    /// - Throws: An error if text generation fails
    public func generateToolCalls(from input: LLMInput) async throws -> GeneratedContent {
        // Convert tools to MLX schema format
        let toolSchemas = tools.map { tool in
            Tool<EmptyInput, EmptyOutput>(
                name: tool.name,
                description: tool.description,
                parameters: convertParametersToMLXFormat(tool.argumentsSchema)
            ) { _ in EmptyOutput() }.schema
        }
        
        // Create chat messages from input
        let chat = input.chatMessages

        // Create UserInput with tools
        var userInput = UserInput(
            chat: chat,
            tools: toolSchemas.isEmpty ? nil : toolSchemas,
            additionalContext: ["enable_thinking": false]
        )
        userInput.processing.resize = CGSize(width: 448, height: 448)

        if chat.contains(where: { !$0.images.isEmpty }), !context.supportsVision {
            throw LLMError.visionUnsupported
        }
        
        let modelContainer = context.modelContainer
        
        let (generatedText, toolCalls) = try await modelContainer.perform { [userInput] (context: ModelContext) -> (String, [LLMToolCall]?) in
            let lmInput = try await context.processor.prepare(input: userInput)
            let stream = try MLXLMCommon.generate(
                input: lmInput,
                parameters: parameter.parameters,
                context: context
            )
            
            var text = ""
            var calls: [LLMToolCall] = []

            for await generation in stream {
                if let chunk = generation.chunk {
                    text += chunk
                }
                
                // Check for tool calls in the generation
                if let toolCall = generation.toolCall {
                    // Convert MLX ToolCall to LLMToolCall
                    let arguments = try JSONEncoder().encode(toolCall.function.arguments)
                    let argumentsString = String(decoding: arguments, as: UTF8.self)

                    let llmToolCall = LLMToolCall(
                        id: UUID().uuidString, // Generate ID since MLX ToolCall doesn't have one
                        name: toolCall.function.name,
                        arguments: argumentsString
                    )
                    calls.append(llmToolCall)
                }
            }
            
            return (text, calls.isEmpty ? nil : calls)
        }
        
        return GeneratedContent(text: generatedText, toolCalls: toolCalls ?? [])
    }


    /// Resumes a conversation with tool outputs
    ///
    /// - Parameters:
    ///   - toolCalls: The tool calls that were made
    ///   - toolOutputs: The outputs from executing the tools (toolCallID, output)
    ///   - originalInput: The original input that generated the tool call
    /// - Returns: The model's response to the tool outputs
    /// - Throws: An error if text generation fails
    public func resume(
        withToolCalls toolCalls: [LLMToolCall],
        toolOutputs: [(String, String)],
        originalInput: LLMInput
    ) async throws -> String {
        guard case let .chat(messages) = originalInput.value else {
            throw LLMError.invalidParameter(reason: "Original input must be a chat")
        }
        
        var updatedMessages = messages

        // Add tool messages for each tool output
        for (toolCallID, output) in toolOutputs {
            updatedMessages.append(.tool(output, toolCallID: toolCallID))
        }
        
        // Create a new input with the updated messages
        let updatedInput = LLMInput.chat(updatedMessages)
        
        // Generate a response to the tool outputs
        return try await generateText(from: updatedInput)
    }
    
    /// Converts tool parameters to MLX format
    func convertParametersToMLXFormat(_ parameters: [String: any Sendable]) -> [ToolParameter] {
        guard let properties = parameters["properties"] as? [String: [String: any Sendable]] else {
            return []
        }
        
        let required = parameters["required"] as? [String] ?? []
        
        return properties.compactMap { key, value in
            guard let type = value["type"] as? String,
                  let description = value["description"] as? String else {
                return nil
            }
            
            let mlxType: ToolParameterType
            switch type {
            case "string":
                mlxType = .string
            case "integer", "number":
                mlxType = .int
            case "boolean":
                mlxType = .bool
            case "array":
                // Check for items schema to determine element type
                if let items = value["items"] as? [String: any Sendable] {
                    if let itemType = items["type"] as? String {
                        let elementType: ToolParameterType
                        switch itemType {
                        case "string":
                            elementType = .string
                        case "integer":
                            elementType = .int
                        case "number":
                            elementType = .double
                        case "boolean":
                            elementType = .bool
                        case "object":
                            // For array of objects, parse the object schema
                            if let objectProperties = items["properties"] as? [String: [String: any Sendable]] {
                                let mlxProperties = convertParametersToMLXFormat([
                                    "properties": objectProperties as [String: any Sendable],
                                    "required": (items["required"] as? [String] ?? []) as [String] as any Sendable
                                ])
                                elementType = .object(properties: mlxProperties)
                            } else {
                                elementType = .object(properties: [])
                            }
                        default:
                            elementType = .string
                        }
                        mlxType = .array(elementType: elementType)
                    } else {
                        mlxType = .array(elementType: .string) // Default to string array
                    }
                } else {
                    mlxType = .array(elementType: .string) // Default to string array
                }
            case "object":
                // Parse object properties if available
                if let objectProperties = value["properties"] as? [String: [String: any Sendable]] {
                    let mlxProperties = convertParametersToMLXFormat([
                        "properties": objectProperties as [String: any Sendable],
                        "required": (value["required"] as? [String] ?? []) as [String] as any Sendable
                    ])
                    mlxType = .object(properties: mlxProperties)
                } else {
                    mlxType = .object(properties: []) // Empty object
                }
            default:
                mlxType = .string
            }
            
            var extraProperties: [String: Any] = [:]
            if let enumValues = value["enum"] as? [String] {
                extraProperties["enum"] = enumValues
            }
            
            if required.contains(key) {
                return ToolParameter.required(key, type: mlxType, description: description, extraProperties: extraProperties.isEmpty ? [:] : extraProperties)
            } else {
                return ToolParameter.optional(key, type: mlxType, description: description, extraProperties: extraProperties.isEmpty ? [:] : extraProperties)
            }
        }
    }
}

// Empty types for parameter conversion
private struct EmptyInput: Codable {}
private struct EmptyOutput: Codable {}

