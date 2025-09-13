import LocalLLMClientCore
import Foundation

/// Protocol for processing tool-related message modifications
protocol ToolInstructionProcessor: Sendable {
    /// Check if the template natively supports tools
    func hasNativeToolSupport(in template: String) -> Bool

    /// Process messages to inject tool instructions if needed
    func processMessages(
        _ messages: [[String: any Sendable]],
        tools: [AnyLLMTool],
        templateHasNativeSupport: Bool
    ) throws(LLMError) -> [[String: any Sendable]]

    /// Generate tool instructions for injection
    func generateToolInstructions(for tools: [AnyLLMTool]) throws(LLMError) -> String
}

/// Standard implementation of tool instruction processing
struct StandardToolInstructionProcessor: ToolInstructionProcessor {
    init() {}

    func hasNativeToolSupport(in template: String) -> Bool {
        template.contains("tools")
    }

    func processMessages(
        _ messages: [[String: any Sendable]],
        tools: [AnyLLMTool],
        templateHasNativeSupport: Bool
    ) throws(LLMError) -> [[String: any Sendable]] {
        guard !tools.isEmpty else {
            return messages
        }

        var processedMessages = messages
        
        if templateHasNativeSupport {
            // For templates with native tool support, add tools field to system message
            processedMessages = injectToolsToSystemMessage(processedMessages, tools: tools)
        }

        // Only add tool instructions if the last message is not a tool message
        if !isLastMessageTool(processedMessages) {
            let toolInstructions = try generateToolInstructions(for: tools)
            processedMessages = injectToolInstructions(processedMessages, instructions: toolInstructions)
        }

        // Convert tool messages to assistant messages if needed
        processedMessages = processToolMessages(processedMessages)

        return processedMessages
    }

    func generateToolInstructions(for tools: [AnyLLMTool]) throws(LLMError) -> String {
        let toolsJSON: String
        do {
            toolsJSON = try tools.toOAICompatJSONString(options: [])
        } catch {
            throw LLMError.invalidParameter(reason: "Failed to serialize tools to JSON: \(error.localizedDescription)")
        }

        return """
        If you decide to invoke any of the function(s), you MUST put it in the format of
        <tool_call>
        {"name": function name, "arguments": dictionary of argument name and its value}
        </tool_call>\n
        You SHOULD NOT include any other text in the response if you call a function
        \(toolsJSON)\n
        """
    }

    private func isLastMessageTool(_ messages: [[String: any Sendable]]) -> Bool {
        guard let lastMessage = messages.last else { return false }
        return lastMessage["role"] as? String == "tool"
    }
    
    private func injectToolInstructions(
        _ messages: [[String: any Sendable]],
        instructions: String
    ) -> [[String: any Sendable]] {
        var processedMessages = messages
        
        // Find or create system message
        if let systemIndex = processedMessages.firstIndex(where: { $0["role"] as? String == "system" }) {
            // Append to existing system message
            processedMessages[systemIndex] = appendToSystemMessage(
                processedMessages[systemIndex],
                instructions: instructions
            )
        } else {
            // Create new system message
            let systemMessage: [String: any Sendable] = [
                "role": "system",
                "content": [["type": "text", "text": instructions]]
            ]
            processedMessages.insert(systemMessage, at: 0)
        }
        
        return processedMessages
    }
    
    private func appendToSystemMessage(
        _ message: [String: any Sendable],
        instructions: String
    ) -> [String: any Sendable] {
        var updatedMessage = message

        if let content = message["content"] {
            if let contentString = content as? String {
                updatedMessage["content"] = contentString + "\n\n" + instructions
            } else if var contentArray = content as? [[String: String]],
                      let textIndex = contentArray.firstIndex(where: { $0["type"] == "text" }),
                      let textContent = contentArray[textIndex]["text"] {
                contentArray[textIndex]["text"] = textContent + "\n\n" + instructions
                updatedMessage["content"] = contentArray
            }
        }

        return updatedMessage
    }

    private func processToolMessages(_ messages: [[String: any Sendable]]) -> [[String: any Sendable]] {
        var processedMessages = messages

        // Convert last tool message to assistant message
        if isLastMessageTool(processedMessages),
           let lastIndex = processedMessages.indices.last {
            processedMessages[lastIndex] = convertToolToAssistant(processedMessages[lastIndex])
        }

        return processedMessages
    }

    private func convertToolToAssistant(_ message: [String: any Sendable]) -> [String: any Sendable] {
        var updatedMessage = message
        updatedMessage["role"] = "assistant"

        if let content = message["content"] {
            if let contentString = content as? String {
                updatedMessage["content"] = "<tool_response>\n\(contentString)\n</tool_response>"
            } else if var contentArray = content as? [[String: String]],
                      let textIndex = contentArray.firstIndex(where: { $0["type"] == "text" }),
                      let textContent = contentArray[textIndex]["text"] {
                contentArray[textIndex]["text"] = "You reply to the user using the following results of the invoked function:\n<tool_response>\n\(textContent)\n</tool_response>"
                updatedMessage["content"] = contentArray
            }
        }

        return updatedMessage
    }
    
    private func injectToolsToSystemMessage(
        _ messages: [[String: any Sendable]],
        tools: [AnyLLMTool]
    ) -> [[String: any Sendable]] {
        var processedMessages = messages
        let toolsJSON = (try? tools.toOAICompatJSONString(options: [])) ?? ""

        // Find or create system message
        if let systemIndex = processedMessages.firstIndex(where: { $0["role"] as? String == "system" }) {
            // Add tools field to existing system message
            var systemMessage = processedMessages[systemIndex]
            systemMessage["tools"] = toolsJSON
            processedMessages[systemIndex] = systemMessage
        } else {
            // Create new system message with tools field
            let systemMessage: [String: any Sendable] = [
                "role": "system",
                "content": [["type": "text", "text": ""]],
                "tools": toolsJSON
            ]
            processedMessages.insert(systemMessage, at: 0)
        }
        
        return processedMessages
    }
}
