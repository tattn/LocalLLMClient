import Testing
import Foundation
@testable import LocalLLMClient
@testable import LocalLLMClientCore
import LocalLLMClientMacros
import LocalLLMClientTestUtilities

@Suite
struct LLMSessionToolCallingTests {
    
    
    // Mock LLM client for testing
    actor MockToolCallingClient: LLMClient {
        let tools: [AnyLLMTool]
        var shouldGenerateToolCalls = true
        var mockToolCalls: [LLMToolCall] = []
        var generateTextCallCount = 0
        var generateToolCallsCallCount = 0
        var responseStreamCallCount = 0
        var resumeCallCount = 0
        
        init(tools: [AnyLLMTool] = []) {
            self.tools = tools
        }
        
        func setMockToolCalls(_ calls: [LLMToolCall]) {
            mockToolCalls = calls
        }
        
        func generateText(from input: LLMInput) async throws -> String {
            generateTextCallCount += 1
            return "Response without tool calls"
        }
        
        func textStream(from input: LLMInput) async throws -> AsyncThrowingStream<String, Error> {
            AsyncThrowingStream { continuation in
                continuation.yield("Streaming ")
                continuation.yield("response")
                continuation.finish()
            }
        }
        
        // Tool calling methods
        func generateToolCalls(from input: LLMInput) async throws -> GeneratedContent {
            generateToolCallsCallCount += 1
            return GeneratedContent(
                text: "I'll use the tools to help you.",
                toolCalls: mockToolCalls
            )
        }
        
        func responseStream(from input: LLMInput) async throws -> AsyncThrowingStream<StreamingChunk, Error> {
            responseStreamCallCount += 1
            return AsyncThrowingStream { continuation in
                Task {
                    continuation.yield(.text("I'll use the tools to help you. "))
                    for toolCall in mockToolCalls {
                        continuation.yield(.toolCall(toolCall))
                    }
                    continuation.finish()
                }
            }
        }
        
        func resume(
            withToolCalls toolCalls: [LLMToolCall],
            toolOutputs: [(String, String)],
            originalInput: LLMInput
        ) async throws -> String {
            resumeCallCount += 1
            // Mock implementation - just return a success message
            return "Based on the tool results: \(toolOutputs.map { $0.1 }.joined(separator: ", "))"
        }
    }
    
    @Test
    func basicToolCallingSession() async throws {
        let weatherTool = WeatherTool()
        let tools: [any LLMTool] = [weatherTool]
        let client = MockToolCallingClient(tools: tools.map { AnyLLMTool($0) })
        
        // Set up mock tool calls
        await client.setMockToolCalls([
            LLMToolCall(
                id: "weather_1",
                name: "get_weather",
                arguments: "{\"location\": \"Tokyo\", \"unit\": \"celsius\"}"
            )
        ])
        
        let model = LLMSession.SystemModel(
            prewarm: { },
            makeClient: { _ in AnyLLMClient(client) }
        )
        
        let session = LLMSession(
            model: model,
            tools: tools.map { $0 }
        )
        
        // Test that tool calls are generated and executed
        let response = try await session.respond(to: "What's the weather in Tokyo?")
        #expect(response.contains("weather") || response.contains("Tokyo") || response.contains("tool results"))
        
        // Verify that respond now uses streamResponse (which uses responseStream for tool calls)
        // The implementation should use responseStream and resume for tool handling
        #expect(await client.responseStreamCallCount >= 1)
        #expect(await client.resumeCallCount >= 1)
        
        // Test streaming response with tools - should only return text
        // Reset mock tool calls for the next request
        await client.setMockToolCalls([
            LLMToolCall(
                id: "weather_2",
                name: "get_weather",
                arguments: "{\"location\": \"Paris\", \"unit\": \"celsius\"}"
            )
        ])
        
        var streamedText = ""
        for try await chunk in session.streamResponse(to: "What's the weather in Paris?") {
            streamedText += chunk
        }
        #expect(streamedText.contains("tool results") || streamedText.contains("Paris"))
    }
    
    
    @Test
    func respondWithoutToolsShouldNotUseResponseStream() async throws {
        // Test that sessions without tools don't use responseStream
        let client = MockToolCallingClient(tools: [])
        
        let model = LLMSession.SystemModel(
            prewarm: { },
            makeClient: { _ in AnyLLMClient(client) }
        )
        
        let session = LLMSession(model: model, tools: [])
        
        let response = try await session.respond(to: "Hello world")
        
        // Should use textStream instead of responseStream
        #expect(await client.responseStreamCallCount == 0)
        #expect(await client.resumeCallCount == 0)
        #expect(response == "Streaming response")
    }
    
    
    @Test
    func sessionWithMultipleTools() async throws {
        let weatherTool = WeatherTool()
        let calculatorTool = CalculatorTool()
        let tools: [any LLMTool] = [weatherTool, calculatorTool]
        
        let client = MockToolCallingClient(tools: tools.map { AnyLLMTool($0) })
        
        let model = LLMSession.SystemModel(
            prewarm: { },
            makeClient: { _ in AnyLLMClient(client) }
        )
        
        let session = LLMSession(model: model, tools: tools)
        
        // Test with calculator request
        await client.setMockToolCalls([
            LLMToolCall(
                id: "calc_1",
                name: "calculate",
                arguments: "{\"expression\": \"2 + 2\"}"
            )
        ])
        
        let response = try await session.respond(to: "What is 2 + 2?")
        #expect(response.contains("4") || response.contains("result"))
    }
    
    // Tool that always fails for testing error handling
    struct FailingTool: LLMTool {
        let name = "failing_tool"
        let description = "A tool that always fails"
        
        @ToolArguments
        struct Arguments {
            @ToolArgument("Error message")
            var message: String
        }
        
        func call(arguments: Arguments) async throws -> ToolOutput {
            throw LLMError.failedToDecode(reason: "Tool execution failed")
        }
    }
    
    @Test
    func sessionToolExecutionError() async throws {
        
        let failingTool = FailingTool()
        let tools: [any LLMTool] = [failingTool]
        let client = MockToolCallingClient(tools: tools.map { AnyLLMTool($0) })
        
        await client.setMockToolCalls([
            LLMToolCall(
                id: "fail_1",
                name: "failing_tool",
                arguments: "{\"message\": \"test\"}"
            )
        ])
        
        let model = LLMSession.SystemModel(
            prewarm: { },
            makeClient: { _ in AnyLLMClient(client) }
        )
        
        let session = LLMSession(model: model, tools: tools)
        
        // Should handle the error gracefully
        do {
            _ = try await session.respond(to: "Use the failing tool")
            Issue.record("Expected error was not thrown")
        } catch {
            // Expected to throw
            #expect(error is LLMSession.ToolCallError)
        }
    }
    
    @Test
    func sessionWithoutToolsEnabledShouldNotExecuteTools() async throws {
        let weatherTool = WeatherTool()
        let _ = [AnyLLMTool(weatherTool)]
        let client = MockToolCallingClient(tools: [])  // No tools for client
        
        // Session without tools
        let model = LLMSession.SystemModel(
            prewarm: { },
            makeClient: { _ in AnyLLMClient(client) }
        )
        
        let session = LLMSession(model: model)
        
        let response = try await session.respond(to: "What's the weather?")
        #expect(response == "Streaming response")
        // Note: When no tools are available, streamResponse is used instead of generateText
        #expect(await client.generateTextCallCount == 0)
    }
    
    @Test
    func sessionToolExecutionTimeout() async throws {
        // Tool that takes longer than expected
        struct SlowTool: LLMTool {
            let name = "slow_tool"
            let description = "A tool that takes time"
            let executionTime: Double
            
            struct Arguments: Decodable, ToolSchemaGeneratable {
                let task: String
                
                static var argumentsSchema: LLMToolArgumentsSchema {
                    ["task": .string(description: "Task to perform")]
                }
            }
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                try await Task.sleep(nanoseconds: UInt64(executionTime * 1_000_000_000))
                return ToolOutput(data: ["task": arguments.task, "status": "completed"])
            }
        }
        
        let slowTool = SlowTool(executionTime: 0.1)
        let tools: [any LLMTool] = [slowTool]
        let client = MockToolCallingClient(tools: tools.map { AnyLLMTool($0) })
        
        await client.setMockToolCalls([
            LLMToolCall(
                id: "slow_1",
                name: "slow_tool",
                arguments: #"{"task": "process data"}"#
            )
        ])
        
        let model = LLMSession.SystemModel(
            prewarm: { },
            makeClient: { _ in AnyLLMClient(client) }
        )
        
        let session = LLMSession(model: model, tools: tools)
        
        // Execute with timeout context
        let start = Date()
        let response = try await session.respond(to: "Process some data")
        let elapsed = Date().timeIntervalSince(start)
        
        // Verify tool executed successfully within reasonable time
        #expect(elapsed >= 0.1)
        #expect(response.contains("process data") || response.contains("completed"))
    }
    
    @Test
    func sessionToolExecutionCancellation() async throws {
        // Tool that can be cancelled
        struct CancellableTool: LLMTool {
            let name = "cancellable_tool"
            let description = "A tool that can be cancelled"
            
            struct Arguments: Decodable, ToolSchemaGeneratable {
                let duration: Double
                
                static var argumentsSchema: LLMToolArgumentsSchema {
                    ["duration": .number(description: "Duration in seconds")]
                }
            }
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                do {
                    try await Task.sleep(nanoseconds: UInt64(arguments.duration * 1_000_000_000))
                    return ToolOutput(data: ["status": "completed"])
                } catch is CancellationError {
                    return ToolOutput(data: ["status": "cancelled"])
                }
            }
        }
        
        let tool = CancellableTool()
        let tools: [any LLMTool] = [tool]
        let client = MockToolCallingClient(tools: tools.map { AnyLLMTool($0) })
        
        await client.setMockToolCalls([
            LLMToolCall(
                id: "cancel_1",
                name: "cancellable_tool",
                arguments: #"{"duration": 5.0}"#
            )
        ])
        
        let model = LLMSession.SystemModel(
            prewarm: { },
            makeClient: { _ in AnyLLMClient(client) }
        )
        
        let session = LLMSession(model: model, tools: tools)
        
        // Start task and cancel it
        let task = Task {
            try await session.respond(to: "Start long task")
        }
        
        // Give it time to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        
        // Cancel the task
        task.cancel()
        
        do {
            _ = try await task.value
        } catch {
            // Expected to throw due to cancellation
            #expect(error is CancellationError || error is LLMSession.ToolCallError)
        }
    }
    
    @Test
    func sessionDynamicToolRegistration() async throws {
        // Test adding/removing tools dynamically
        var currentTools: [any LLMTool] = [WeatherTool()]
        let client = MockToolCallingClient(tools: currentTools.map { AnyLLMTool($0) })
        
        let model = LLMSession.SystemModel(
            prewarm: { },
            makeClient: { _ in AnyLLMClient(client) }
        )
        
        // Create session with initial tools
        var session = LLMSession(model: model, tools: currentTools)
        
        // Test with weather tool
        await client.setMockToolCalls([
            LLMToolCall(
                id: "weather_1",
                name: "get_weather",
                arguments: #"{"location": "Tokyo", "unit": "celsius"}"#
            )
        ])
        
        let response1 = try await session.respond(to: "What's the weather?")
        #expect(response1.contains("weather") || response1.contains("Tokyo"))
        
        // Add calculator tool dynamically
        currentTools.append(CalculatorTool())
        session = LLMSession(model: model, tools: currentTools)
        
        // Update client tools
        await client.setMockToolCalls([
            LLMToolCall(
                id: "calc_1",
                name: "calculate",
                arguments: #"{"expression": "5 + 5"}"#
            )
        ])
        
        let response2 = try await session.respond(to: "What is 5 + 5?")
        #expect(response2.contains("10") || response2.contains("result"))
    }
}