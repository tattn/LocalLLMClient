import Testing
import Foundation
import LocalLLMClient
@testable import LocalLLMClientLlama

extension ModelTests {
    struct LlamaChatMessageDecoderTests {}
}

extension ModelTests.LlamaChatMessageDecoderTests {
    @Test
    func checkTemplate() async throws {
        let client = try await LocalLLMClient.llama()
        let decoder = LlamaAutoMessageDecoder(context: client._context) //LlamaQwen2VLMessageDecoder()
        let messages: [LLMInput.Message] = [
            .system("You are a helpful assistant."),
            .user("What is the answer to one plus two?"),
            .assistant("The answer is 3."),
        ]
        let value = decoder.templateValue(from: messages)
        let template = try decoder.applyTemplate(value, context: client._context)
        #expect(template == "<|im_start|>System: You are a helpful assistant.<end_of_utterance>\nUser: What is the answer to one plus two?<end_of_utterance>\nAssistant: The answer is 3.<end_of_utterance>\nAssistant:")
    }
}
