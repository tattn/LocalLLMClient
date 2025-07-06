import Testing
import Foundation
import LocalLLMClientCore
import LocalLLMClientLlama
import LocalLLMClientTestUtilities

extension ModelTests {
    @Suite(.serialized, .timeLimit(.minutes(5)))
    struct LLMSessionLlamaTests {
        
        private static func makeGeneralModel(size: LocalLLMClient.ModelSize = .default) -> LLMSession.DownloadModel {
            let info = LocalLLMClient.modelInfo(for: .general, modelSize: size)
            return .llama(id: info.id, model: info.model, mmproj: info.clip)
        }
        
        private static func makeToolModel(size: LocalLLMClient.ModelSize = .default) -> LLMSession.DownloadModel {
            let info = LocalLLMClient.modelInfo(for: .tool, modelSize: size)
            return .llama(id: info.id, model: info.model, mmproj: info.clip, parameter: .init(context: 1536))
        }
        
        @Test
        func simpleRespond() async throws {
            let session = LLMSession(model: Self.makeGeneralModel())
            print(try await session.respond(to: "What is 1 plus 2?"))
            print(try await session.respond(to: "What is the previous answer plus 4?"))
        }
        
        @Test
        func simpleStreamResponse() async throws {
            let session = LLMSession(model: Self.makeGeneralModel())
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
        func respondWithImage() async throws {
            let session = LLMSession(model: Self.makeGeneralModel())
            let imageData = try Data(contentsOf: URL(string: "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/cats.jpeg")!)
            print(try await session.respond(to: "What's in this image", attachments: [
                .image(.init(data: imageData)!)
            ]))
        }
        
        @Test
        func simpleToolCall() async throws {
            // Create a test weather tool that tracks invocations
            let weatherTool = TestWeatherTool()
            
            // Use tool test type model for better tool support
            let session = LLMSession(
                model: Self.makeToolModel(),
                tools: [weatherTool]
            )
            
            // Ask a question that should trigger tool use
            let response = try await session.respond(to: "What's the weather like in Tokyo? use get_weather")
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
        func toolCallWithMultipleTools() async throws {
            // Create test tools
            let weatherTool = TestWeatherTool()
            let calculatorTool = TestCalculatorTool()
            
            let session = LLMSession(
                model: Self.makeToolModel(),
                tools: [weatherTool, calculatorTool]
            )
            
            // Test calculator
            weatherTool.reset()
            calculatorTool.reset()
            
            let calcResponse = try await session.respond(to: "What is 2 + 2? use calculate")
            print("Calculator response: \(calcResponse)")
            
            #expect(calculatorTool.invocationCount > 0, "Calculator tool should have been called")
            #expect(weatherTool.invocationCount == 0, "Weather tool should not have been called for calculation")
            #expect(calcResponse.contains("4"), "Response should contain the result")
            
            // Test weather
            weatherTool.reset()
            calculatorTool.reset()

            let weatherResponse = try await session.respond(to: "What's the weather in Paris? use get_weather")
            print("Weather response: \(weatherResponse)")
            
            #expect(weatherTool.invocationCount > 0, "Weather tool should have been called")
            #expect(calculatorTool.invocationCount == 0, "Calculator tool should not have been called for weather")
            
            if let lastArgs = weatherTool.lastArguments {
                #expect(lastArgs.location.lowercased().contains("paris"), "Tool should have been called with Paris as location")
            }
        }
    }
}
