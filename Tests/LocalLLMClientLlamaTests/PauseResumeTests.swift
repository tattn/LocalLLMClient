import Testing
import LocalLLMClientCore
import LocalLLMClientLlama
import Foundation

@Suite("Pause/Resume Tests")
struct PauseResumeTests {
    
    @Test("Test pause and resume during generation")
    func testPauseAndResume() async throws {
        // Create a mock LLM client
        let mockClient = MockLLMClient()
        
        // Initial state should not be paused
        #expect(await mockClient.isGenerationPaused == false)
        
        // Pause generation
        await mockClient.pauseGeneration()
        #expect(await mockClient.isGenerationPaused == true)
        
        // Resume generation
        await mockClient.resumeGeneration()
        #expect(await mockClient.isGenerationPaused == false)
    }
    
    @Test("Test AnyLLMClient pause/resume forwarding")
    func testAnyLLMClientPauseResume() async throws {
        let mockClient = MockLLMClient()
        let anyClient = AnyLLMClient(mockClient)
        
        // Initial state
        #expect(await anyClient.isGenerationPaused == false)
        
        // Pause through AnyLLMClient
        await anyClient.pauseGeneration()
        #expect(await anyClient.isGenerationPaused == true)
        #expect(await mockClient.isGenerationPaused == true)
        
        // Resume through AnyLLMClient
        await anyClient.resumeGeneration()
        #expect(await anyClient.isGenerationPaused == false)
        #expect(await mockClient.isGenerationPaused == false)
    }
}

// Mock implementation for testing
actor MockLLMClient: LLMClient {
    private var isPaused = false
    
    func pauseGeneration() async {
        isPaused = true
    }
    
    func resumeGeneration() async {
        isPaused = false
    }
    
    var isGenerationPaused: Bool {
        get async {
            isPaused
        }
    }
    
    func generateText(from input: LLMInput) async throws -> String {
        return "Mock response"
    }
    
    func textStream(from input: LLMInput) async throws -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                // Simulate streaming with pause check
                for i in 0..<5 {
                    while await isGenerationPaused {
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    continuation.yield("Token \(i) ")
                }
                continuation.finish()
            }
        }
    }
    
    func generateToolCalls(from input: LLMInput) async throws -> GeneratedContent {
        throw LLMError.invalidParameter(reason: "Not implemented")
    }
    
    func resume(withToolCalls toolCalls: [LLMToolCall], toolOutputs: [(String, String)], originalInput: LLMInput) async throws -> String {
        throw LLMError.invalidParameter(reason: "Not implemented")
    }
    
    func responseStream(from input: LLMInput) async throws -> AsyncThrowingStream<StreamingChunk, Error> {
        throw LLMError.invalidParameter(reason: "Not implemented")
    }
}