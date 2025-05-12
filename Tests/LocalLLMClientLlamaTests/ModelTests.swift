import Testing
import Foundation
import LocalLLMClient
@testable import LocalLLMClientLlama
import LocalLLMClientUtility

private let disabledTests = ![nil, "Llama"].contains(ProcessInfo.processInfo.environment["GITHUB_ACTIONS_TEST"])

extension LocalLLMClient {
    static let model = "SmolVLM-256M-Instruct-Q8_0.gguf"
    static let clip = "mmproj-SmolVLM-256M-Instruct-Q8_0.gguf"

    static func llama(parameter: LlamaClient.Parameter? = nil) async throws -> LlamaClient {
        let url = try await downloadModel()
        return try await LocalLLMClient.llama(
            url: url.appending(component: model),
            clipURL: url.appending(component: clip),
            parameter: parameter ?? .init(context: 512),
            messageDecoder: LlamaCustomMessageDecoder(tokenImageStart: "<|test_img|>", tokenImageEnd: "<|end_test_img|>"),
            verbose: true
        )
    }

    static func downloadModel() async throws -> URL {
        let downloader = FileDownloader(
            source: .huggingFace(id: "ggml-org/SmolVLM-256M-Instruct-GGUF", globs: [model, clip]),
            destination: ProcessInfo.processInfo.environment["GITHUB_MODEL_CACHE"].map { URL(filePath: $0) } ?? FileDownloader.defaultRootDestination
        )
        return try await downloader.download { print("Download: \($0)") }
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
}
