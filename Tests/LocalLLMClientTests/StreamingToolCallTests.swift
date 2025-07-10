import Testing
@testable import LocalLLMClientCore
import Foundation

@Suite
struct StreamingToolCallTests {
    
    @Test
    func testLLMClientStreamWithToolCalls() async throws {
        // Test that LLMClient returns both text and tool calls
        let mockClient = MockStreamingToolCallClient()
        
        var collectedText = ""
        var collectedToolCalls: [LLMToolCall] = []
        
        // Stream directly from client - should get both text and tool calls
        for try await content in try await mockClient.responseStream(from: .plain("Search for weather")) {
            switch content {
            case .text(let text):
                collectedText += text
            case .toolCall(let toolCall):
                collectedToolCalls.append(toolCall)
            }
        }
        
        // Verify client returns both text and tool calls
        #expect(collectedText.contains("Let me search"))
        #expect(collectedToolCalls.count == 1)
        #expect(collectedToolCalls[0].name == "search")
    }
    
    @Test
    func testLLMSessionStreamOnlyText() async throws {
        // Test that LLMSession only returns text (handles tool calls internally)
        struct TestTool: LLMTool {
            struct Arguments: Codable, Sendable, ToolSchemaGeneratable {
                let query: String
                
                static var argumentsSchema: LLMToolArgumentsSchema {
                    [
                        "query": .string(description: "The search query")
                    ]
                }
            }
            
            let name = "search"
            let description = "Search for information"
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                ToolOutput(data: ["result": "Found information about \(arguments.query)"])
            }
        }
        
        let mockClient = MockStreamingToolCallClient()
        let session = LLMSession(
            model: LLMSession.SystemModel(
                prewarm: {},
                makeClient: { _ in AnyLLMClient(mockClient) }
            ),
            tools: [TestTool()]
        )
        
        var collectedText = ""
        
        // Stream response from session - should only get text
        for try await text in session.streamResponse(to: "Search for weather in Tokyo") {
            collectedText += text
        }
        
        // Verify session handled tool calls internally and returned processed text
        #expect(collectedText.contains("Let me search") || collectedText.contains("Found information"))
    }
    
    @Test
    func testStreamingToolCallProcessor() throws {
        let processor = StreamingToolCallProcessor()
        
        // Test streaming chunks
        let chunks = [
            "Let me search for that. ",
            "<tool_call>",
            "{\"name\": \"search\", ",
            "\"arguments\": {\"query\": \"weather\"}}",
            "</tool_call>",
            " Here are the results."
        ]
        
        var outputText = ""
        
        for chunk in chunks {
            if let text = processor.processChunk(chunk) {
                outputText += text
            }
        }
        
        #expect(outputText == "Let me search for that.  Here are the results.")
        #expect(processor.toolCalls.count == 1)
        #expect(processor.toolCalls[0].name == "search")
    }
    
    @Test
    func testPartialToolCallDetection() throws {
        let processor = StreamingToolCallProcessor()
        
        // Test partial tag detection
        #expect(processor.processChunk("Normal text ") == "Normal text ")
        #expect(processor.processChunk("<") == nil) // Potential tool call
        #expect(processor.processChunk("tool_") == nil) // Still collecting
        #expect(processor.processChunk("call>") == nil) // Complete tag
        #expect(processor.processChunk("{\"name\":\"test\"}") == nil) // Tool content
        #expect(processor.processChunk("</tool_call>") == nil) // End tag
        #expect(processor.processChunk(" More text") == " More text")
        
        #expect(processor.toolCalls.count == 1)
        #expect(processor.toolCalls[0].name == "test")
    }
}

// Mock client for testing
private final class MockStreamingToolCallClient: LLMClient, @unchecked Sendable {
    func generateText(from input: LLMInput) async throws -> String {
        "Mock response"
    }
    
    func textStream(from input: LLMInput) async throws -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { _ in }
    }
    
    func generateToolCalls(from input: LLMInput) async throws -> GeneratedContent {
        GeneratedContent(text: "Mock response")
    }
    
    func resume(withToolCalls toolCalls: [LLMToolCall], toolOutputs: [(String, String)], originalInput: LLMInput) async throws -> String {
        "Found information about weather"
    }
    
    func responseStream(from input: LLMInput) async throws -> AsyncThrowingStream<StreamingChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                continuation.yield(.text("Let me search for that. "))
                continuation.yield(.toolCall(LLMToolCall(
                    name: "search",
                    arguments: "{\"query\": \"weather in Tokyo\"}"
                )))
                continuation.yield(.text("Found information about weather"))
                continuation.finish()
            }
        }
    }
}
