#if canImport(FoundationModels)
import LocalLLMClient
import FoundationModels
import LocalLLMClientUtility
import Foundation

@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public extension LLMSession.Model {
    static func foundationModels(
        model: SystemLanguageModel = .default,
        parameter: GenerationOptions = .init()
    ) -> LLMSession.SystemModel {
        return LLMSession.SystemModel(
            prewarm: { LanguageModelSession(model: model).prewarm() },
            makeClient: {
                try await AnyLLMClient(
                    LocalLLMClient.foundationModels(model: model, parameter: parameter)
                )
            }
        )
    }
}
#endif
