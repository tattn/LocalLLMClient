import Testing
import Foundation
import LocalLLMClientCore
@testable import LocalLLMClientMLX
import LocalLLMClientTestUtilities
import LocalLLMClientMacros

extension ModelTests {
    struct LocalLLMClientMLXToolTests {}
}

// Test tool definitions
@ToolArguments
struct AsyncToolArguments {
    @ToolArgument("Delay in seconds")
    var delay: Double
}

struct AsyncTool: LLMTool {
    let name = "async_operation"
    let description = "Performs an async operation"
    
    typealias Arguments = AsyncToolArguments
    
    func call(arguments: Arguments) async throws -> ToolOutput {
        // Simulate async work
        try await Task.sleep(nanoseconds: UInt64(arguments.delay * 1_000_000_000))
        return ToolOutput(data: ["completed": true, "delay": arguments.delay])
    }
}

extension ModelTests.LocalLLMClientMLXToolTests {
    // Note: MLXClient doesn't fully support tool calling yet
    // These tests verify basic structure and API compatibility
    
    @Test
    func mlxToolSchemaGeneration() async throws {
        // Test MLX-specific schema generation
        let weatherTool = WeatherTool()
        let anyTool = AnyLLMTool(weatherTool)
        
        let schema = anyTool.toOAICompatJSON()
        #expect(schema["type"] as? String == "function")
        
        let function = schema["function"] as? [String: Any]
        #expect(function?["name"] as? String == "get_weather")
        #expect(function?["description"] as? String == weatherTool.description)
        
        let parameters = function?["parameters"] as? [String: Any]
        #expect(parameters?["type"] as? String == "object")
        
        let properties = parameters?["properties"] as? [String: Any]
        #expect(properties?.keys.contains("location") == true)
        #expect(properties?.keys.contains("unit") == true)
    }
    
    @Test
    func mlxAsyncToolSupport() async throws {
        // Test async tool execution in MLX context
        let asyncTool = AsyncTool()
        let anyTool = AnyLLMTool(asyncTool)
        
        // Test tool execution
        let startTime = Date()
        let result = try await anyTool.call(argumentsJSON: #"{"delay": 0.1}"#)
        let elapsed = Date().timeIntervalSince(startTime)
        
        #expect(elapsed >= 0.1) // Verify async delay occurred
        
        // Check result
        #expect(result.data["completed"] as? Bool == true)
        #expect(result.data["delay"] as? Double == 0.1)
    }
    
    @Test
    func mlxToolArgumentValidation() async throws {
        let calculatorTool = CalculatorTool()
        let anyTool = AnyLLMTool(calculatorTool)
        
        // Test with valid arguments
        let validResult = try await anyTool.call(argumentsJSON: #"{"expression": "2 + 2"}"#)
        #expect(validResult.data["result"] as? Double == 4)
        
        // Test with invalid arguments
        do {
            _ = try await anyTool.call(argumentsJSON: #"{"invalid": "field"}"#)
            Issue.record("Expected error for invalid arguments")
        } catch {
            // Expected to throw
            #expect(error is ToolError)
        }
    }
    
    @Test  
    func mlxToolArrayArguments() async throws {
        let arrayTool = ArrayTool()
        let anyTool = AnyLLMTool(arrayTool)
        
        let result = try await anyTool.call(argumentsJSON: #"{"items": ["a", "b", "c"], "tags": ["tag1", "tag2"]}"#)
        
        #expect(result.data["processed_count"] as? Int == 3)
        #expect(result.data["items"] as? [String] == ["a", "b", "c"])
        #expect(result.data["tags"] as? [String] == ["tag1", "tag2"])
    }
    
    @Test
    func mlxToolOptionalParameters() async throws {
        let optionalTool = OptionalParamTool()
        let anyTool = AnyLLMTool(optionalTool)
        
        // Test with only required parameters
        let minimalResult = try await anyTool.call(argumentsJSON: #"{"query": "test"}"#)
        #expect(minimalResult.data["query"] as? String == "test")
        #expect(minimalResult.data["limit"] as? Int == 10) // Default value
        #expect(minimalResult.data["category"] as? String == "all") // Default value
        
        // Test with all parameters
        let fullResult = try await anyTool.call(argumentsJSON: #"{"query": "test", "limit": 20, "category": "news", "sortOrder": "date"}"#)
        #expect(fullResult.data["query"] as? String == "test")
        #expect(fullResult.data["limit"] as? Int == 20)
        #expect(fullResult.data["category"] as? String == "news")
        #expect(fullResult.data["sortOrder"] as? String == "date")
    }
}
