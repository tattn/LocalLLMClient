#if canImport(FoundationModels)
import Testing
import Foundation
import LocalLLMClientCore
import LocalLLMClientFoundationModels
import LocalLLMClientTestUtilities

extension ModelTests {
    @Suite(.serialized, .timeLimit(.minutes(5)))
    struct LLMSessionFoundationModelsTests {
        
        @Test
        @available(macOS 26.0, *)
        func simpleRespond() async throws {
            let session = LLMSession(model: .foundationModels())
            print(try await session.respond(to: "1 + 2 = ?"))
            print(try await session.respond(to: "What is the previous answer plus 4?"))
        }
        
        @Test
        @available(macOS 26.0, *)
        func simpleStreamResponse() async throws {
            let session = LLMSession(model: .foundationModels())
            for try await text in session.streamResponse(to: "What is 1 plus 2?") {
                print(text, terminator: "")
            }
            print()
            for try await text in session.streamResponse(to: "What is the previous answer plus 4?") {
                print(text, terminator: "")
            }
            print()
        }
        
        @Test
        @available(macOS 26.0, *)
        func simpleToolCall() async throws {
            // Create a test weather tool that tracks invocations
            let weatherTool = TestWeatherTool()
            
            // Create session with tools
            let session = LLMSession(
                model: .foundationModels(),
                tools: [weatherTool]
            )
            
            // Ask a question that should trigger tool use
            let response = try await session.respond(to: "What's the weather like in Tokyo?")
            print("Response: \(response)")
            
            // Verify the tool was actually called
            #expect(weatherTool.invocationCount > 0, "Weather tool should have been called at least once")
            
            // Verify the tool was called with correct arguments
            if let lastArgs = weatherTool.lastArguments {
                #expect(lastArgs.location.lowercased().contains("tokyo"), "Tool should have been called with Tokyo as location")
            } else {
                Issue.record("Tool arguments were not captured")
            }
            
            // The response should contain weather information
            #expect(response.contains("Tokyo") || response.contains("weather") || response.contains("temperature") || response.contains("22") || response.contains("72"))
        }
        
        @Test
        @available(macOS 26.0, *)
        func toolCallWithMultipleTools() async throws {
            // Create test tools
            let weatherTool = TestWeatherTool()
            let calculatorTool = TestCalculatorTool()
            
            let session = LLMSession(
                model: .foundationModels(),
                tools: [weatherTool, calculatorTool]
            )
            
            // Test calculator
            weatherTool.reset()
            calculatorTool.reset()
            
            let calcResponse = try await session.respond(to: "What is 2 + 2?")
            print("Calculator response: \(calcResponse)")
            
            #expect(calculatorTool.invocationCount > 0, "Calculator tool should have been called")
            #expect(weatherTool.invocationCount == 0, "Weather tool should not have been called for calculation")
            #expect(calcResponse.contains("4"), "Response should contain the result")
            
            // Test weather
            weatherTool.reset()
            calculatorTool.reset()
            
            let weatherResponse = try await session.respond(to: "What's the weather in Paris?")
            print("Weather response: \(weatherResponse)")
            
            #expect(weatherTool.invocationCount > 0, "Weather tool should have been called")
            #expect(calculatorTool.invocationCount == 0, "Calculator tool should not have been called for weather")
            
            if let lastArgs = weatherTool.lastArguments {
                #expect(lastArgs.location.lowercased().contains("paris"), "Tool should have been called with Paris as location")
            }
        }
    }
}
#endif
