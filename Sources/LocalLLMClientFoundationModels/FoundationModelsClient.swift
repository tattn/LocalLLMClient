#if canImport(FoundationModels)
import LocalLLMClientCore
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public final actor FoundationModelsClient: LLMClient {
    /// Defines additional options for the FoundationModels client.
    public struct Options: Sendable {
        /// Initializes a new set of options for the FoundationModels client.
        ///
        /// - Parameters:
        ///   - disableAutoPause: If `true`, disables automatic pausing when the app goes to background on iOS. Default is `false`.
        public init(
            disableAutoPause: Bool = false
        ) {
            self.disableAutoPause = disableAutoPause
        }
        
        /// If `true`, disables automatic pausing when the app goes to background on iOS.
        public var disableAutoPause: Bool
    }
    
    let model: SystemLanguageModel
    let generationOptions: GenerationOptions
    let pauseHandler: PauseHandler

    init(
        model: SystemLanguageModel,
        generationOptions: GenerationOptions,
        options: Options = .init()
    ) {
        self.model = model
        self.generationOptions = generationOptions
        self.pauseHandler = PauseHandler(disableAutoPause: options.disableAutoPause)
    }

    public func textStream(from input: LLMInput) async throws -> AsyncStream<String> {
        return .init { continuation in
            let task = Task {
                do {
                    var position: String.Index?
                    let session = LanguageModelSession(model: model, transcript: input.makeTranscript(generationOptions: generationOptions))
                    for try await text in session.streamResponse(to: input.makePrompt(), options: generationOptions) {
                        await pauseHandler.checkPauseState()
                        continuation.yield(String(text.content[(position ?? text.content.startIndex)...]))
                        position = text.content.endIndex
                    }
                } catch {
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    /// Pauses any ongoing text generation
    public func pauseGeneration() async {
        await pauseHandler.pause()
    }
    
    /// Resumes previously paused text generation
    public func resumeGeneration() async {
        await pauseHandler.resume()
    }
    
    /// Whether the generation is currently paused
    public var isGenerationPaused: Bool {
        get async {
            await pauseHandler.isPaused
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension LLMInput {
    func makePrompt() -> Prompt {
        Prompt {
            switch value {
            case let .plain(text):
                text
            case let .chatTemplate(messages):
                messages.last?.value["content"] as? String ?? ""
            case let .chat(messages):
                messages.last?.content ?? ""
            }
        }
    }
    
    func makeTranscript(generationOptions: GenerationOptions) -> Transcript {
        .init(entries: makeEntriesWithoutLatest(generationOptions: generationOptions))
    }
    
    private func makeEntriesWithoutLatest(generationOptions: GenerationOptions) -> [Transcript.Entry] {
        switch value {
        case .plain:
            []
        case let .chatTemplate(messages):
            messages.dropLast().compactMap { message in
                let content = message.value["content"] as? String ?? ""
                let role = message.value["role"] as? String
                return makeTranscriptEntry(role: role, content: content, generationOptions: generationOptions)
            }
        case let .chat(messages):
            messages.dropLast().compactMap { message in
                let role: String? = switch message.role {
                case .system: "system"
                case .user, .custom: "user"
                case .assistant: "assistant"
                case .tool: "tool"
                }
                return makeTranscriptEntry(role: role, content: message.content, generationOptions: generationOptions)
            }
        }
    }
    
    private func makeTranscriptEntry(role: String?, content: String, generationOptions: GenerationOptions) -> Transcript.Entry? {
        switch role {
        case "system"?:
            return .instructions(.init(
                segments: [.text(.init(content: content))],
                toolDefinitions: []
            ))
        case "user"?:
            return .prompt(.init(
                segments: [.text(.init(content: content))],
                options: generationOptions
            ))
        case "assistant"?:
            return .response(.init(
                assetIDs: [], segments: [.text(.init(content: content))]
            ))
        case "tool"?:
            return .prompt(.init(
                segments: [.text(.init(content: content))],
                options: generationOptions
            ))
        default:
            return nil
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public extension LocalLLMClient {
    static func foundationModels(
        model: SystemLanguageModel = .default,
        parameter: GenerationOptions = .init(),
        options: FoundationModelsClient.Options = .init()
    ) async throws -> FoundationModelsClient {
        FoundationModelsClient(model: model, generationOptions: parameter, options: options)
    }
}

#endif
