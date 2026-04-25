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
    private func buildChatParams(tools: [any LLMTool]) async throws -> (LlamaClient, UnsafeMutablePointer<llm_chat_params>?) {
        let client = try await LocalLLMClient.llama(tools: tools, testType: .tool)
        let wrapped = tools.map { AnyLLMTool($0) }
        let params = client._context.model.buildChatParams(tools: wrapped)
        return (client, params)
    }

    private func makeToolCallResponse(
        name: String,
        argumentsJSON: String,
        client: LlamaClient
    ) throws -> String {
        if usesQwen35XMLToolCallSyntax(chatTemplate: client._context.model.chatTemplate) {
            let argumentsData = try #require(argumentsJSON.data(using: .utf8))
            let argumentsObject = try JSONSerialization.jsonObject(with: argumentsData)
            let qwen35Parameters = try #require(renderQwen35Parameters(argumentsObject))
            return """
            <tool_call>
            <function=\(name)>
            \(qwen35Parameters)
            </function>
            </tool_call>
            """
        }

        switch client.chatFormat {
        case COMMON_CHAT_FORMAT_PEG_GEMMA4:
            let argumentsData = try #require(argumentsJSON.data(using: .utf8))
            let argumentsObject = try JSONSerialization.jsonObject(with: argumentsData)
            let gemmaArguments = try #require(renderGemma4Arguments(argumentsObject))
            return "<|tool_call>call:\(name)\(gemmaArguments)<tool_call|>"
        default:
            return """
            <tool_call>
            {"name": "\(name)", "arguments": \(argumentsJSON)}
            </tool_call>
            """
        }
    }

    private func usesQwen35XMLToolCallSyntax(chatTemplate: String) -> Bool {
        chatTemplate.contains("<function=") && chatTemplate.contains("<parameter=")
    }

    private func renderQwen35Parameters(_ value: Any) -> String? {
        guard let object = value as? [String: Any] else {
            return nil
        }

        return object.keys.sorted().map { key in
            let value = object[key]!
            return """
            <parameter=\(key)>
            \(renderQwen35Value(value))
            </parameter>
            """
        }
        .joined(separator: "\n")
    }

    private func renderQwen35Value(_ value: Any) -> String {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        case _ as NSNull:
            return "null"
        default:
            let data = try? JSONSerialization.data(withJSONObject: value)
            return data.flatMap { String(data: $0, encoding: .utf8) } ?? String(describing: value)
        }
    }

    private func renderGemma4Arguments(_ value: Any) -> String? {
        guard let object = value as? [String: Any] else {
            return nil
        }

        let renderedPairs = object.keys.sorted().map { key in
            let value = object[key]!
            return "\(key):\(renderGemma4Value(value))"
        }
        return "{\(renderedPairs.joined(separator: ","))}"
    }

    private func renderGemma4Value(_ value: Any) -> String {
        switch value {
        case let string as String:
            return #"<|\"|>\#(string)<|\"|>"#
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        case _ as NSNull:
            return "null"
        case let array as [Any]:
            return "[\(array.map(renderGemma4Value).joined(separator: ","))]"
        case let dictionary as [String: Any]:
            let pairs = dictionary.keys.sorted().map { key in
                let value = dictionary[key]!
                return "\(key):\(renderGemma4Value(value))"
            }
            return "{\(pairs.joined(separator: ","))}"
        default:
            fatalError("Unsupported Gemma 4 argument type: \(type(of: value))")
        }
    }

    @Test
    func parseToolCallFromModelNativeResponse() async throws {
        let (client, chatParams) = try await buildChatParams(tools: [WeatherTool()])
        defer { if let chatParams { free_chat_params(chatParams) } }

        let response = try makeToolCallResponse(
            name: "get_weather",
            argumentsJSON: #"{"location":"Tokyo","unit":"celsius"}"#,
            client: client
        )

        let calls = LlamaToolCallParser.parseToolCalls(from: response, chatParams: chatParams)
        try #require(calls != nil, "Expected tool calls to be extracted from a well-formed response")
        #expect(calls?.count == 1)
        #expect(calls?.first?.name == "get_weather")
        #expect(calls?.first?.id.isEmpty == false, "An auto-generated UUID should be assigned when the model omits an id")
        #expect(calls?.first?.arguments.contains("Tokyo") == true)
    }

    @Test
    func parseToolCallWithDeclaredToolSet() async throws {
        let (client, chatParams) = try await buildChatParams(tools: [WeatherTool(), CalculatorTool()])
        defer { if let chatParams { free_chat_params(chatParams) } }

        let response = try makeToolCallResponse(
            name: "calculate",
            argumentsJSON: #"{"expression":"15 * 4"}"#,
            client: client
        )

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
