import Testing
import Foundation
import LocalLLMClientCore
@testable import LocalLLMClientLlama
import LocalLLMClientTestUtilities

#if BUILD_DOCC
@preconcurrency @_implementationOnly import llama
#elseif canImport(llama)
@preconcurrency private import llama
#else
@preconcurrency import LocalLLMClientLlamaC
#endif

extension ModelTests {
    struct LocalLLMClientLlamaToolTests {}
}

extension ModelTests.LocalLLMClientLlamaToolTests {
    private func makeToolClient() async throws -> LlamaClient {
        try await LocalLLMClient.llama(
            testType: .tool,
            // Qwen2.5 uses <tool_call> tags; tools must be declared so the PEG parser
            // includes the tool-call grammar branches.
            // These tools come from LocalLLMClientTestUtilities (WeatherTool, CalculatorTool).
        )
    }

    private func buildChatParams(tools: [any LLMTool]) async throws -> (LlamaClient, UnsafeMutablePointer<llm_chat_params>?) {
        let client = try await LocalLLMClient.llama(tools: tools, testType: .tool)
        let wrapped = tools.map { AnyLLMTool($0) }
        let params = client._context.model.buildChatParams(tools: wrapped)
        return (client, params)
    }

    @Test
    func parseToolCallFromHermesStyleResponse() async throws {
        let (_, chatParams) = try await buildChatParams(tools: [WeatherTool()])
        defer { if let chatParams { free_chat_params(chatParams) } }

        let response = """
        <tool_call>
        {"name": "get_weather", "arguments": {"location": "Tokyo", "unit": "celsius"}}
        </tool_call>
        """

        let calls = LlamaToolCallParser.parseToolCalls(from: response, chatParams: chatParams)
        try #require(calls != nil, "Expected tool calls to be extracted from a well-formed response")
        #expect(calls?.count == 1)
        #expect(calls?.first?.name == "get_weather")
        #expect(calls?.first?.arguments.contains("Tokyo") == true)
    }

    @Test
    func parseToolCallWithCalculatorTool() async throws {
        let (_, chatParams) = try await buildChatParams(tools: [WeatherTool(), CalculatorTool()])
        defer { if let chatParams { free_chat_params(chatParams) } }

        let response = """
        <tool_call>
        {"name": "calculate", "arguments": {"expression": "15 * 4"}}
        </tool_call>
        """

        let calls = LlamaToolCallParser.parseToolCalls(from: response, chatParams: chatParams)
        try #require(calls != nil)
        #expect(calls?.first?.name == "calculate")
        #expect(calls?.first?.arguments.contains("15 * 4") == true)
    }

    @Test
    func parseResponseWithoutToolCalls() async throws {
        let (_, chatParams) = try await buildChatParams(tools: [WeatherTool()])
        defer { if let chatParams { free_chat_params(chatParams) } }

        let calls = LlamaToolCallParser.parseToolCalls(
            from: "This is a plain response without any tool calls.",
            chatParams: chatParams
        )
        #expect(calls == nil)
    }

    @Test
    func parseEmptyResponse() async throws {
        let (_, chatParams) = try await buildChatParams(tools: [WeatherTool()])
        defer { if let chatParams { free_chat_params(chatParams) } }

        let calls = LlamaToolCallParser.parseToolCalls(from: "", chatParams: chatParams)
        #expect(calls == nil)
    }

    @Test
    func parseToolCallAssignsIDWhenMissing() async throws {
        let (_, chatParams) = try await buildChatParams(tools: [WeatherTool()])
        defer { if let chatParams { free_chat_params(chatParams) } }

        let response = """
        <tool_call>
        {"name": "get_weather", "arguments": {"location": "Tokyo", "unit": "celsius"}}
        </tool_call>
        """

        let calls = LlamaToolCallParser.parseToolCalls(from: response, chatParams: chatParams)
        try #require(calls?.first != nil)
        #expect(!calls!.first!.id.isEmpty, "An auto-generated UUID should be assigned when the model omits an id")
    }

    @Test
    func parseToolCallsReturnsNilWhenChatParamsIsNil() {
        // Guard clause: a missing chatParams pointer must not crash and must return nil.
        let calls = LlamaToolCallParser.parseToolCalls(
            from: "<tool_call>{\"name\":\"x\",\"arguments\":{}}</tool_call>",
            chatParams: nil
        )
        #expect(calls == nil)
    }

    @Test
    func chatFormatIsReportedForToolClient() async throws {
        let client = try await LocalLLMClient.llama(tools: [WeatherTool()], testType: .tool)
        let format = client.chatFormat
        let validFormats: [common_chat_format] = [
            COMMON_CHAT_FORMAT_CONTENT_ONLY,
            COMMON_CHAT_FORMAT_PEG_SIMPLE,
            COMMON_CHAT_FORMAT_PEG_NATIVE,
            COMMON_CHAT_FORMAT_PEG_GEMMA4,
        ]
        #expect(validFormats.contains(format), "Unexpected chat format: \(format)")
    }
}
