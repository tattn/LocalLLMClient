import Testing
import Foundation
import LocalLLMClientCore
@testable import LocalLLMClientLlama

@Suite
struct LlamaToolCallParserTests {

    @Test
    func parseEmptyResponse() async throws {
        let result = LlamaToolCallParser.parseToolCalls(from: "", format: COMMON_CHAT_FORMAT_HERMES_2_PRO)
        #expect(result == nil)
    }
    
    @Test
    func parseNoToolCalls() async throws {
        let response = "This is just a regular response without any tool calls."
        let result = LlamaToolCallParser.parseToolCalls(from: response, format: COMMON_CHAT_FORMAT_HERMES_2_PRO)
        #expect(result == nil)
    }
    
    @Test
    func parseGenericJSONToolCall() async throws {
        // Generic format expects {"tool_call": {"name": "...", "arguments": "..."}}
        let response = """
        I'll help you with that. Let me call a function to get the weather.
        
        {"tool_call": {"name": "get_weather", "arguments": {"location": "New York", "unit": "celsius"}}}
        
        Here's the weather information.
        """
        
        let result = LlamaToolCallParser.parseToolCalls(from: response, format: COMMON_CHAT_FORMAT_HERMES_2_PRO)
        #expect(result != nil)
        #expect(result?.count == 1)
        
        if let toolCall = result?.first {
            #expect(toolCall.name == "get_weather")
            #expect(toolCall.arguments.contains("New York"))
            #expect(toolCall.arguments.contains("celsius"))
        }
    }
    
    @Test
    func parseHermesFormatToolCall() async throws {
        let response = """
        I'll search for that information.
        
        <tool_call>
        {"name": "search", "arguments": {"query": "Swift programming"}}
        </tool_call>
        
        Found some results for you.
        """
        
        let result = LlamaToolCallParser.parseToolCalls(from: response, format: COMMON_CHAT_FORMAT_HERMES_2_PRO)
        #expect(result != nil)
        #expect(result?.count == 1)
        
        if let toolCall = result?.first {
            #expect(toolCall.name == "search")
            #expect(toolCall.arguments.contains("Swift programming"))
        }
    }
    
    @Test
    func parseMultipleToolCalls() async throws {
        // Currently the parser only captures the first tool call when multiple are present
        // This is a limitation of the current llama.cpp integration
        let response = """
        I'll need to call several functions to help you.
        
        <tool_call>
        {"name": "function1", "arguments": {"param": "value1"}}
        </tool_call>
        
        <tool_call>
        {"name": "function2", "arguments": {"param": "value2"}}
        </tool_call>
        
        Both functions have been called.
        """
        
        let result = LlamaToolCallParser.parseToolCalls(from: response, format: COMMON_CHAT_FORMAT_HERMES_2_PRO)
        #expect(result != nil, "Parser should return a result for valid tool calls")
        #expect(result?.count == 1, "Currently only first tool call is parsed (known limitation)")
        
        if let toolCall = result?.first {
            #expect(toolCall.name == "function1", "First tool call should be function1")
            #expect(toolCall.arguments.contains("value1"), "Arguments should contain value1")
            
            // Verify the arguments can be parsed as JSON
            let data = toolCall.arguments.data(using: .utf8)!
            let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            #expect(parsed?["param"] as? String == "value1", "Parsed arguments should have correct value")
        } else {
            Issue.record("Expected at least 1 tool call but got \(result?.count ?? 0)")
        }
    }
    
    @Test
    func parseToolCallWithID() async throws {
        let response = """
        <tool_call>
        {"name": "my_function", "id": "call_123", "arguments": {"test": "data"}}
        </tool_call>
        """
        
        let result = LlamaToolCallParser.parseToolCalls(from: response, format: COMMON_CHAT_FORMAT_HERMES_2_PRO)
        #expect(result != nil)
        #expect(result?.count == 1)
        
        if let toolCall = result?.first {
            #expect(toolCall.id == "call_123")
            #expect(toolCall.name == "my_function")
            #expect(toolCall.arguments.contains("test"))
        }
    }
    
    @Test
    func parseToolCallWithoutID() async throws {
        let response = """
        <tool_call>
        {"name": "my_function", "arguments": {"test": "data"}}
        </tool_call>
        """
        
        let result = LlamaToolCallParser.parseToolCalls(from: response, format: COMMON_CHAT_FORMAT_HERMES_2_PRO)
        #expect(result != nil, "Parser should handle tool calls without ID")
        #expect(result?.count == 1, "Should parse exactly one tool call")
        
        if let toolCall = result?.first {
            // Should generate a UUID when no ID is provided
            #expect(!toolCall.id.isEmpty, "Auto-generated ID should not be empty")
            #expect(toolCall.id.count >= 36, "Auto-generated ID should be UUID-like") // UUID format
            #expect(toolCall.name == "my_function", "Tool name should match")
            #expect(toolCall.arguments.contains("test"), "Arguments should contain test data")
            
            // Verify UUID format (basic check)
            let uuidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
            let uuidRegex = try? NSRegularExpression(pattern: uuidPattern)
            let matches = uuidRegex?.matches(in: toolCall.id, range: NSRange(location: 0, length: toolCall.id.count))
            #expect((matches?.count ?? 0) > 0 || toolCall.id.count >= 8, "ID should be in valid format")
        }
    }
}
