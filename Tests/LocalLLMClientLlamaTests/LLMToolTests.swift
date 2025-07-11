import Testing
import Foundation
import LocalLLMClientCore
import LocalLLMClientMacros
@testable import LocalLLMClientLlama
import LocalLLMClientTestUtilities

extension ModelTests {
    struct LLMToolTests {}
}

extension ModelTests.LLMToolTests {
    
    @Test func toolJSONConversion() {
        let tool = WeatherTool()
        let anyTool = AnyLLMTool(tool)
        let json = anyTool.toOAICompatJSON()
        
        #expect(json["type"] as? String == "function")
        
        guard let functionDict = json["function"] as? [String: Any] else {
            Issue.record("Missing function dictionary in JSON")
            return
        }
        
        #expect(functionDict["name"] as? String == "get_weather")
        #expect(functionDict["description"] as? String == "Get the current weather for a location")
        #expect(functionDict["parameters"] is [String: Any])
    }
    
    @Test func toolsInTemplate() throws {
        let tool = WeatherTool()
        let processor = MessageProcessorFactory.chatMLProcessor()
        let messages: [LLMInput.Message] = [
            .user("What's the weather like in San Francisco?")
        ]
        
        let template = """
        {{- bos_token }}
        {% if tools %}
        Available tools:
        {% for tool in tools %}
        {{ tool.function.name }}: {{ tool.function.description }}
        {% endfor %}
        {% endif %}
        {% for message in messages %}
        {{ message.role }}: {{ message.content }}
        {% endfor %}
        """
        
        let (result, _) = try processor.renderAndExtractChunks(
            messages: messages,
            template: template,
            specialTokens: ["bos_token": "<s>"],
            tools: [AnyLLMTool(tool)]
        )
        
        #expect(result.contains("Available tools:"))
        #expect(result.contains("get_weather: Get the current weather for a location"))
        #expect(result.contains("user: What's the weather like in San Francisco?"))
    }
    
    @Test func toolOutputProperties() async throws {
        let tool = WeatherTool()
        let anyTool = AnyLLMTool(tool)
        let output = try await anyTool.call(argumentsJSON: #"{"location": "San Francisco, CA", "unit": "celsius"}"#)
        
        // Verify the structured properties
        #expect(output.data["location"] as? String == "San Francisco, CA")
        #expect(output.data["temperature"] != nil)
        #expect(output.data["unit"] as? String == "celsius")
        #expect(output.data["conditions"] != nil)
    }
    
    // Note: CalculatorTool is now provided by CommonTestTools
    
    @Test func toolOutputCalculation() async throws {
        let tool = CalculatorTool()
        let anyTool = AnyLLMTool(tool)
        let output = try await anyTool.call(argumentsJSON: #"{"expression": "10 * 5"}"#)
        
        // Verify the structured properties
        #expect(output.data["result"] as? Double == 50)
        #expect(output.data["expression"] as? String == "10 * 5")
    }
    
    @Test func toolOutputErrorHandling() async throws {
        let tool = CalculatorTool()
        let anyTool = AnyLLMTool(tool)
        let output = try await anyTool.call(argumentsJSON: #"{"expression": "invalid expression"}"#)
        
        #expect(output.data["result"] as? Double == 0)
        #expect(output.data["expression"] as? String == "invalid expression")
    }
}
