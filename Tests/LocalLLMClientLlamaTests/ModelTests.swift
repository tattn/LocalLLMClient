import Testing
import Foundation
import LocalLLMClientCore
@testable import LocalLLMClientLlama
import LocalLLMClientUtility
import LocalLLMClientTestUtilities

extension LocalLLMClient {
    enum TestType {
        case tool
        case general
    }
    
    enum ModelSize {
        case light
        case normal
        
        static var `default`: ModelSize {
            if TestEnvironment.onGitHubAction {
                return .light
            } else {
                return .normal
            }
        }
    }
    
    static func modelInfo(for testType: TestType, modelSize: ModelSize = .default) -> (id: String, model: String, clip: String?) {
        let size = modelSize
        
        switch testType {
        case .tool:
            switch size {
            case .light:
                return (
                    id: "Qwen/Qwen2.5-0.5B-Instruct-GGUF",
                    model: "qwen2.5-0.5b-instruct-q8_0.gguf",
                    clip: nil
                )
            case .normal:
                return (
                    id: "Qwen/Qwen2.5-1.5B-Instruct-GGUF",
                    model: "qwen2.5-1.5b-instruct-q4_k_m.gguf",
                    clip: nil
                )
            }
        case .general:
            switch size {
            case .light:
                return (
                    id: "ggml-org/SmolVLM-256M-Instruct-GGUF",
                    model: "SmolVLM-256M-Instruct-Q8_0.gguf",
                    clip: "mmproj-SmolVLM-256M-Instruct-Q8_0.gguf"
                )
            case .normal:
                return (
                    id: "lmstudio-community/gemma-3-4B-it-qat-GGUF",
                    model: "gemma-3-4B-it-QAT-Q4_0.gguf",
                    clip: "mmproj-model-f16.gguf"
                )
            }
        }
    }
    

    static func llama(
        parameter: LlamaClient.Parameter? = nil,
        messageProcessor: MessageProcessor? = nil,
        tools: [any LLMTool] = [],
        testType: TestType = .general,
        modelSize: ModelSize = .default
    ) async throws -> LlamaClient {
        let modelInfo = modelInfo(for: testType, modelSize: modelSize)
        let url = try await downloadModel(testType: testType, modelSize: modelSize)
        let modelURL = url.appending(component: modelInfo.model)
        print("Loading model from: \(modelURL.path)")
        print("Model info: \(modelInfo)")
        
        // Use provided processor or default based on test type
        let processor: MessageProcessor?
        if testType == .general && messageProcessor == nil {
            // Create a custom processor with regex-based image extraction
            processor = MessageProcessor(
                transformer: StandardMessageTransformer(),
                renderer: JinjaChatTemplateRenderer(),
                chunkExtractor: RegexChunkExtractor(imageTokenPattern: #"<\|test_img\|>"#),
                llamaDecoder: StandardLlamaDecoder()
            )
        } else {
            processor = messageProcessor
        }
        
        return try await LocalLLMClient.llama(
            url: modelURL,
            mmprojURL: modelInfo.clip.map { url.appending(component: $0) },
            parameter: parameter ?? .init(context: 512, options: .init(verbose: true)),
            messageProcessor: processor,
            tools: tools
        )
    }

    static func downloadModel(testType: TestType = .general, modelSize: ModelSize = .default) async throws -> URL {
        let modelInfo = modelInfo(for: testType, modelSize: modelSize)
        var globs = [modelInfo.model]
        if let clip = modelInfo.clip {
            globs.append(clip)
        }
        let downloader = FileDownloader(
            source: .huggingFace(id: modelInfo.id, globs: Globs(globs)),
            destination: ProcessInfo.processInfo.environment["GITHUB_MODEL_CACHE"].map { URL(filePath: $0) } ?? FileDownloader.defaultRootDestination
        )
        try await downloader.download { print("Download: \($0)") }
        return downloader.destination
    }
}

@Suite(.serialized, .timeLimit(.minutes(5)), .disabled(if: disabledTests))
actor ModelTests {
    nonisolated(unsafe) private static var initialized = false

    init() async throws {
        if !Self.initialized && !disabledTests {
            // Determine which models need to be downloaded
            let modelConfigs: [(testType: LocalLLMClient.TestType, modelSize: LocalLLMClient.ModelSize)] = [
                (.general, LocalLLMClient.ModelSize.default),  // Default size for general tests
                (.general, .light),                           // Light model for template tests
                (.tool, LocalLLMClient.ModelSize.default)     // Default size for tool tests
            ]
            
            // Download required models
            await withTaskGroup(of: Void.self) { group in
                for config in modelConfigs {
                    group.addTask {
                        do {
                            let url = try await LocalLLMClient.downloadModel(testType: config.testType, modelSize: config.modelSize)
                            let modelInfo = LocalLLMClient.modelInfo(for: config.testType, modelSize: config.modelSize)
                            let modelPath = url.appending(component: modelInfo.model).path
                            if !FileManager.default.fileExists(atPath: modelPath) {
                                print("Warning: \(config.testType) \(config.modelSize) model file not found at \(modelPath)")
                            } else {
                                print("Downloaded \(config.testType) \(config.modelSize) model: \(modelInfo.id)")
                            }
                        } catch {
                            print("Failed to download \(config.testType) \(config.modelSize) model: \(error)")
                        }
                    }
                }
            }
            
            Self.initialized = true
        }
    }

    @Test
    func validateChatTemplate() async throws {
        let client = try await LocalLLMClient.llama(testType: .general, modelSize: .light)
        #expect(client._context.model.chatTemplate == """
        <|im_start|>{% for message in messages %}{{message[\'role\'] | capitalize}}{% if message[\'content\'][0][\'type\'] == \'image\' %}{{\':\'}}{% else %}{{\': \'}}{% endif %}{% for line in message[\'content\'] %}{% if line[\'type\'] == \'text\' %}{{line[\'text\']}}{% elif line[\'type\'] == \'image\' %}{{ \'<image>\' }}{% endif %}{% endfor %}<end_of_utterance>\n{% endfor %}{% if add_generation_prompt %}{{ \'Assistant:\' }}{% endif %}
        """)
    }

    @Test
    func validateRenderedTemplate() async throws {
        let client = try await LocalLLMClient.llama(testType: .general, modelSize: .light)
        let processor = MessageProcessorFactory.createAutoProcessor(chatTemplate: client._context.model.chatTemplate)
        let messages: [LLMInput.Message] = [
            .system("You are a helpful assistant."),
            .user("What is the answer to one plus two?"),
            .assistant("The answer is 3."),
        ]
        
        let (rendered, _) = try processor.renderAndExtractChunks(
            messages: messages,
            template: client._context.model.chatTemplate
        )
        
        // Check that template was rendered correctly
        #expect(rendered.contains("You are a helpful assistant."))
        #expect(rendered.contains("What is the answer to one plus two?"))
        #expect(rendered.contains("The answer is 3."))
    }
}
