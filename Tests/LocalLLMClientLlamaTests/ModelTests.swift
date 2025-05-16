import Testing
import Foundation
import LocalLLMClient
@testable import LocalLLMClientLlama
import LocalLLMClientUtility

let disabledTests = ![nil, "Llama"].contains(ProcessInfo.processInfo.environment["GITHUB_ACTIONS_TEST"])

extension LocalLLMClient {
    static let model = "SmolVLM-256M-Instruct-Q8_0.gguf"
    static let clip = "mmproj-SmolVLM-256M-Instruct-Q8_0.gguf"

    static func llama(parameter: LlamaClient.Parameter? = nil) async throws -> LlamaClient {
        let url = try await downloadModel()
        return try await LocalLLMClient.llama(
            url: url.appending(component: model),
            mmprojURL: url.appending(component: clip),
            parameter: parameter ?? .init(context: 512),
            messageDecoder: LlamaCustomMessageDecoder(tokenImageRegex: #"<\|test_img\|>"#),
            verbose: true
        )
    }

    static func downloadModel() async throws -> URL {
        let downloader = FileDownloader(
            source: .huggingFace(id: "ggml-org/SmolVLM-256M-Instruct-GGUF", globs: [model, clip]),
            destination: ProcessInfo.processInfo.environment["GITHUB_MODEL_CACHE"].map { URL(filePath: $0) } ?? FileDownloader.defaultRootDestination
        )
        try await downloader.download { print("Download: \($0)") }
        return downloader.destination
    }
}

@Suite(.serialized, .timeLimit(.minutes(5)), .disabled(if: disabledTests))
actor ModelTests {
    private static var initialized = false

    init() async throws {
        if !Self.initialized && !disabledTests {
            _ = try await LocalLLMClient.downloadModel()
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
