import Foundation
import LocalLLMClient
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import Tokenizers

public final class Context {
    let modelContainer: ModelContainer

    public init(url: URL) async throws(LLMError) {
        initializeMLX()

        MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

        let configuration = ModelConfiguration(directory: url)

        let baseConfig: BaseConfiguration
        let model: any LanguageModel
        let tokenizer: any Tokenizer

        do {
            let configurationURL = url.appending(component: "config.json")
            baseConfig = try JSONDecoder().decode(
                BaseConfiguration.self, from: Data(contentsOf: configurationURL)
            )
            model = try LLMTypeRegistry.shared.createModel(
                configuration: configurationURL,
                modelType: baseConfig.modelType
            )

            try loadWeights(modelDirectory: url, model: model, quantization: baseConfig.quantization)

            tokenizer = try await loadTokenizer(configuration: configuration, hub: .shared)
        } catch {
            throw .failedToLoad
        }

        let context = ModelContext(
            configuration: configuration, model: model,
            processor: LLMUserInputProcessor(
                tokenizer: tokenizer,
                configuration: configuration,
                messageGenerator: DefaultMessageGenerator()
            ),
            tokenizer: tokenizer
        )
        modelContainer = ModelContainer(context: context)
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

