import Testing
import Foundation
import LocalLLMClient
@testable import LocalLLMClientLlama
#if canImport(LocalLLMClientUtility)
import LocalLLMClientUtility
#endif

let disabledTests = ![nil, "Llama"].contains(ProcessInfo.processInfo.environment["GITHUB_ACTIONS_TEST"])

extension LocalLLMClient {
    static let model = "SmolVLM-256M-Instruct-Q8_0.gguf"
    static let clip = "mmproj-SmolVLM-256M-Instruct-Q8_0.gguf"

    static func llama(
        parameter: LlamaClient.Parameter? = nil,
        messageDecoder: any LlamaChatMessageDecoder = LlamaCustomMessageDecoder(tokenImageRegex: #"<\|test_img\|>"#)
    ) async throws -> LlamaClient {
        let url = try await downloadModel()
        return try await LocalLLMClient.llama(
            url: url.appending(component: model),
            mmprojURL: url.appending(component: clip),
            parameter: parameter ?? .init(context: 512, options: .init(verbose: true)),
            messageDecoder: messageDecoder
        )
    }

    static func downloadModel() async throws -> URL {
#if canImport(LocalLLMClientUtility)
        let downloader = FileDownloader(
            source: .huggingFace(id: "ggml-org/SmolVLM-256M-Instruct-GGUF", globs: [model, clip]),
            destination: ProcessInfo.processInfo.environment["GITHUB_MODEL_CACHE"].map { URL(filePath: $0) } ?? FileDownloader.defaultRootDestination
        )
        try await downloader.download { print("Download: \($0)") }
        return downloader.destination
#else
        return URL(filePath: ProcessInfo.processInfo.environment["GITHUB_MODEL_CACHE", default: "~/.localllmclient"])
            .appending(component: "huggingface/models/ggml-org/SmolVLM-256M-Instruct-GGUF")
#endif
    }
}

@Suite(.serialized, .timeLimit(.minutes(5)), .disabled(if: disabledTests))
actor ModelTests {
    nonisolated(unsafe) private static var initialized = false

    init() async throws {
        if !Self.initialized && !disabledTests {
            let url = try await LocalLLMClient.downloadModel()
            let path = url.appending(component: LocalLLMClient.model).path
            if !FileManager.default.fileExists(atPath: path) {
                throw LLMError.failedToLoad(reason: "Model file not found at \(path)")
            }
            Self.initialized = true
        }
    }

    @Test
    func validateChatTemplate() async throws {
        let client = try await LocalLLMClient.llama()
        #expect(client._context.model.chatTemplate == """
        <|im_start|>{% for message in messages %}{{message[\'role\'] | capitalize}}{% if message[\'content\'][0][\'type\'] == \'image\' %}{{\':\'}}{% else %}{{\': \'}}{% endif %}{% for line in message[\'content\'] %}{% if line[\'type\'] == \'text\' %}{{line[\'text\']}}{% elif line[\'type\'] == \'image\' %}{{ \'<image>\' }}{% endif %}{% endfor %}<end_of_utterance>\n{% endfor %}{% if add_generation_prompt %}{{ \'Assistant:\' }}{% endif %}
        """)
    }

    @Test
    func validateRenderedTemplate() async throws {
        let client = try await LocalLLMClient.llama()
        let decoder = LlamaAutoMessageDecoder(chatTemplate: client._context.model.chatTemplate)
        let messages: [LLMInput.Message] = [
            .system("You are a helpful assistant."),
            .user("What is the answer to one plus two?"),
            .assistant("The answer is 3."),
        ]
        let value = decoder.templateValue(from: messages)
        let template = try decoder.applyTemplate(value, chatTemplate: client._context.model.chatTemplate)
        #expect(decoder.chatTemplate == .qwen2_5_VL)
        #expect(template == "<|im_start|>System: You are a helpful assistant.<end_of_utterance>\nUser: What is the answer to one plus two?<end_of_utterance>\nAssistant: The answer is 3.<end_of_utterance>\nAssistant:")
    }
}
