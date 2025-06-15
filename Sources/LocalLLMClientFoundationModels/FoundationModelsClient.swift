#if canImport(FoundationModels)
import LocalLLMClient
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public final actor FoundationModelsClient: LLMClient {
    let generationOptions: GenerationOptions

    init(generationOptions: GenerationOptions) {
        self.generationOptions = generationOptions
    }

    public func textStream(from input: LLMInput) async throws -> AsyncStream<String> {
        return .init { continuation in
            let task = Task {
                do {
                    var position: String.Index?
                    let session = LanguageModelSession(transcript: input.makeTranscript(generationOptions: generationOptions))
                    for try await text in session.streamResponse(to: input.makePrompt(), options: generationOptions) {
                        continuation.yield(String(text[(position ?? text.startIndex)...]))
                        position = text.endIndex
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
            messages.dropLast().compactMap {
                let content = $0.value["content"] as? String ?? ""
//                let images = $0.attachments.images // not supported yet
                switch $0.value["role"] as? String {
                case "system"?:
                    return Transcript.Entry.instructions(.init(
                        segments: [.text(.init(content: content))],
                        toolDefinitions: []
                    ))
                case "user"?:
                    return Transcript.Entry.prompt(.init(
                        segments: [.text(.init(content: content))],
                        options: generationOptions
                    ))
                case "assistant"?:
                    return Transcript.Entry.response(.init(
                        assetIDs: [], segments: [.text(.init(content: content))]
                    ))
                default:
                    return nil
                }
            }
        case let .chat(messages):
            messages.dropLast().compactMap {
                let content = $0.content
                switch $0.role {
                case .system:
                    return Transcript.Entry.instructions(.init(
                        segments: [.text(.init(content: content))],
                        toolDefinitions: []
                    ))
                case .user, .custom:
                    return Transcript.Entry.prompt(.init(
                        segments: [.text(.init(content: content))],
                        options: generationOptions
                    ))
                case .assistant:
                    return Transcript.Entry.response(.init(
                        assetIDs: [], segments: [.text(.init(content: content))]
                    ))
                }
            }
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public extension LocalLLMClient {
    static func foundationModels(
        model: SystemLanguageModel = .default,
        parameter: GenerationOptions = .init()
    ) async throws -> FoundationModelsClient {
        FoundationModelsClient(generationOptions: parameter)
    }
}

#endif
