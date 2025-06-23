import Foundation
import LocalLLMClientUtility

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@Observable
public final class LLMSession {
    public init<T: Model>(model: T, messages: [LLMInput.Message] = []) {
        generator = Generator(model: model, messages: messages)
    }

    let generator: Generator

    public var messages: [LLMInput.Message] {
        get { generator.messages }
        set { generator.messages = newValue }
    }

    public func prewarm() async throws {
        try await generator.prewarm()
    }

    public func respond(to prompt: String, attachments: [LLMAttachment] = []) async throws -> String {
        try await streamResponse(to: prompt, attachments: attachments).reduce("", +)
    }

    public func streamResponse(to prompt: String, attachments: [LLMAttachment] = []) -> AsyncThrowingStream<String, any Error> {
        generator.streamResponse(to: prompt, attachments: attachments)
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension LLMSession {
    @_disfavoredOverload
    public convenience init(model: LLMSession.DownloadModel, messages: [LLMInput.Message] = []) {
        self.init(model: model, messages: messages)
    }

    @_disfavoredOverload
    public convenience init(model: LLMSession.SystemModel, messages: [LLMInput.Message] = []) {
        self.init(model: model, messages: messages)
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension LLMSession {
    @Observable
    final class Generator: Sendable {
        public nonisolated init(model: any Model, messages: [LLMInput.Message]) {
            self.model = model
            self._messages = Locked(messages)
        }

        let model: any Model
        private let client = Locked<AnyLLMClient?>(nil)
        private let _messages: Locked<[LLMInput.Message]>

        @ObservationIgnored
        var messages: [LLMInput.Message] {
            get {
                access(keyPath: \.messages)
                return _messages.withLock(\.self)
            }
            set {
                withMutation(keyPath: \.messages) {
                    _messages.withLock { message in
                        message = newValue
                    }
                }
            }
        }

        public func prewarm() async throws {
            let client = try await loadClient()
            self.client.withLock { $0 = client }
        }

        private func loadClient() async throws -> AnyLLMClient {
            if let client = client.withLock(\.self) {
                return client
            }

            try await model.prewarm()

            let client = try await model.makeClient()
            self.client.withLock { $0 = client }
            return client
        }

        nonisolated func streamResponse(to prompt: String, attachments: [LLMAttachment]) -> AsyncThrowingStream<String, any Error> {
            return AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        let client = try await loadClient()
                        messages.append(.user(prompt, attachments: attachments))

                        var collectedResponse = ""
                        let stream = try await client.textStream(from: .chat(messages))
                        for try await chunk in stream {
                            collectedResponse += chunk
                            continuation.yield(chunk)
                        }
                        // Add the complete response as an assistant message
                        messages.append(.assistant(collectedResponse))
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { @Sendable _ in
                    task.cancel()
                }
            }
        }
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public extension LLMSession {
    protocol Model: Sendable {
        var makeClient: @Sendable () async throws -> AnyLLMClient { get }

        func prewarm() async throws
    }

    struct SystemModel: Model {
        public let prewarm: @Sendable () async throws -> Void
        public let makeClient: @Sendable () async throws -> AnyLLMClient

        package init(
            prewarm: @Sendable @escaping () async throws -> Void,
            makeClient: @Sendable @escaping () async throws -> AnyLLMClient
        ) {
            self.prewarm = prewarm
            self.makeClient = makeClient
        }

        public func prewarm() async throws {
            try await prewarm()
        }
    }

    struct DownloadModel: Model {
        let source: FileDownloader.Source
        let downloader: FileDownloader
        public let makeClient: @Sendable () async throws -> AnyLLMClient

        package init(source: FileDownloader.Source, makeClient: @Sendable @escaping () async throws -> AnyLLMClient) {
            self.source = source
#if os(iOS)
            let identifier = switch source {
            case .huggingFace(let id, _):
                "localllmclient.llmsession.\(id)"
            }
            downloader = FileDownloader(
                source: source,
                configuration: .background(withIdentifier: identifier)
            )
#else
            downloader = FileDownloader(source: source)
#endif
            self.makeClient = makeClient
        }

        public func prewarm() async throws {
            try await downloadModel()
        }

        public func downloadModel(onProgress: @Sendable @escaping (Double) async -> Void = { _ in }) async throws {
            try await downloader.download(onProgress: onProgress)
        }
    }
}
