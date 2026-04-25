import Foundation
import MLXVLM
import LocalLLMClientCore
import MLX
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import Tokenizers

public final class Context: Sendable {
    let modelContainer: ModelContainer
    let supportsVision: Bool

    public init(url: URL, parameter: MLXClient.Parameter) async throws(LLMError) {
        initializeMLX()

        MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

        let configuration = ModelConfiguration(directory: url, extraEOSTokens: parameter.options.extraEOSTokens)

        let (model, tokenizer) = try await Self.loadModel(
            url: url, configuration: configuration
        )
        let (processor, supportsVision) = await Self.makeProcessor(
            url: url, configuration: configuration, tokenizer: tokenizer
        )

        let context = ModelContext(
            configuration: configuration,
            model: model,
            processor: processor,
            tokenizer: tokenizer
        )
        modelContainer = ModelContainer(context: context)
        self.supportsVision = supportsVision
    }

    private static func loadModel(
        url: URL, configuration: ModelConfiguration
    ) async throws(LLMError) -> (any LanguageModel, any MLXLMCommon.Tokenizer) {
        do {
            let configurationURL = url.appending(component: "config.json")
            let configurationData = try Data(contentsOf: configurationURL)
            let baseConfiguration = try JSONDecoder().decode(
                BaseConfiguration.self, from: configurationData
            )
            let model: any LanguageModel
            do {
                model = try await VLMTypeRegistry.shared.createModel(
                    configuration: configurationData,
                    modelType: baseConfiguration.modelType
                )
            } catch {
                model = try await LLMTypeRegistry.shared.createModel(
                    configuration: configurationData,
                    modelType: baseConfiguration.modelType
                )
            }

            try loadWeights(modelDirectory: url, model: model, perLayerQuantization: baseConfiguration.perLayerQuantization)

            let tokenizerLoader: any MLXLMCommon.TokenizerLoader = #huggingFaceTokenizerLoader()
            let tokenizer = try await tokenizerLoader.load(from: url)
            return (model, tokenizer)
        } catch {
            throw .failedToLoad(reason: error.localizedDescription)
        }
    }

    private static func makeProcessor(
        url: URL, configuration: ModelConfiguration, tokenizer: any MLXLMCommon.Tokenizer,
    ) async -> (any UserInputProcessor, Bool) {
        do {
            let preprocessorURL = url.appending(component: "preprocessor_config.json")
            let processorURL = url.appending(component: "processor_config.json")
            let configURL = FileManager.default.fileExists(atPath: preprocessorURL.path)
                ? preprocessorURL
                : processorURL
            let configurationData = try Data(contentsOf: configURL)
            let baseProcessorConfig = try JSONDecoder().decode(
                BaseProcessorConfiguration.self,
                from: configurationData
            )

            return await (try VLMProcessorTypeRegistry.shared.createModel(
                configuration: configurationData,
                processorType: baseProcessorConfig.processorClass,
                tokenizer: tokenizer
            ), true)
        } catch {
            return (LLMUserInputProcessor(
                tokenizer: tokenizer,
                configuration: configuration,
                messageGenerator: DefaultMessageGenerator()
            ), false)
        }
    }
}

private struct LLMUserInputProcessor: UserInputProcessor {
    let tokenizer: MLXLMCommon.Tokenizer
    let configuration: ModelConfiguration
    let messageGenerator: MessageGenerator

    init(
        tokenizer: any MLXLMCommon.Tokenizer, configuration: ModelConfiguration,
        messageGenerator: MessageGenerator
    ) {
        self.tokenizer = tokenizer
        self.configuration = configuration
        self.messageGenerator = messageGenerator
    }

    func prepare(input: UserInput) throws -> LMInput {
        let messages = messageGenerator.generate(from: input)
        do {
            let promptTokens = try tokenizer.applyChatTemplate(
                messages: messages, tools: input.tools, additionalContext: input.additionalContext
            )
            return LMInput(tokens: MLXArray(promptTokens))
        } catch {
            let prompt = messages
                .compactMap { $0["content"] as? String }
                .joined(separator: "\n\n")
            let promptTokens = tokenizer.encode(text: prompt)
            return LMInput(tokens: MLXArray(promptTokens))
        }
    }
}

