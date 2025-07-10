import Foundation
import MLXVLM
import LocalLLMClientCore
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
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
        let (processor, supportsVision) = Self.makeProcessor(
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
    ) async throws(LLMError) -> (any LanguageModel, any Tokenizer) {
        do {
            let configurationURL = url.appending(component: "config.json")
            let baseConfiguration = try JSONDecoder().decode(
                BaseConfiguration.self, from: Data(contentsOf: configurationURL)
            )
            let model: any LanguageModel
            do {
                model = try VLMTypeRegistry.shared.createModel(
                    configuration: configurationURL,
                    modelType: baseConfiguration.modelType
                )
            } catch {
                model = try LLMTypeRegistry.shared.createModel(
                    configuration: configurationURL,
                    modelType: baseConfiguration.modelType
                )
            }

            try loadWeights(modelDirectory: url, model: model, perLayerQuantization: baseConfiguration.perLayerQuantization)

            let tokenizer = try await loadTokenizer(configuration: configuration, hub: .shared)
            return (model, tokenizer)
        } catch {
            throw .failedToLoad(reason: error.localizedDescription)
        }
    }

    private static func makeProcessor(
        url: URL, configuration: ModelConfiguration, tokenizer: any Tokenizer,
    ) -> (any UserInputProcessor, Bool) {
        do {
            let processorConfiguration = url.appending(
                component: "preprocessor_config.json"
            )
            let baseProcessorConfig = try JSONDecoder().decode(
                BaseProcessorConfiguration.self,
                from: Data(contentsOf: processorConfiguration)
            )

            return (try VLMProcessorTypeRegistry.shared.createModel(
                configuration: processorConfiguration,
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
    let tokenizer: Tokenizer
    let configuration: ModelConfiguration
    let messageGenerator: MessageGenerator

    init(
        tokenizer: any Tokenizer, configuration: ModelConfiguration,
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

