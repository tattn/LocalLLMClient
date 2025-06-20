import Foundation
import LocalLLMClientUtility

public final class LLMSession {
    public init<T: Model>(model: T) {
        generator = Generator(model: model)
    }

    let generator: Generator

    public func prewarm() async throws {
        try await generator.prewarm()
    }

    public func respond(to prompt: String) async throws -> String {
        try await streamResponse(to: prompt).reduce("", +)
    }

    public func streamResponse(to prompt: String) -> AsyncThrowingStream<String, any Error> {
        generator.streamResponse(to: prompt)
    }
}

extension LLMSession {
    @_disfavoredOverload
    public convenience init(model: LLMSession.DownloadModel) {
        self.init(model: model)
    }

    @_disfavoredOverload
    public convenience init(model: LLMSession.SystemModel) {
        self.init(model: model)
    }
}

extension LLMSession {
    final actor Generator {
        public init(model: Model) {
            self.model = model
        }

        let model: Model
        private var client: AnyLLMClient?
        var messages: [LLMInput.Message] = []

        public func prewarm() async throws {
            client = try await loadClient()
        }

        private func loadClient() async throws -> AnyLLMClient {
            if let client {
                return client
            }

            try await model.prewarm()

            let client = try await model.makeClient()
            self.client = client
            return client
        }

        nonisolated func streamResponse(to prompt: String) -> AsyncThrowingStream<String, any Error> {
            return AsyncThrowingStream { continuation in
                let task = Task { @MainActor in
                    do {
                        let client = try await loadClient()
                        await addMessage(.user(prompt))

                        var collectedResponse = ""
                        let stream = try await client.textStream(from: .chat(messages))
                        for try await chunk in stream {
                            collectedResponse += chunk
                            continuation.yield(chunk)
                        }
                        // Add the complete response as an assistant message
                        await addMessage(.assistant(collectedResponse))
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

        private func addMessage(_ message: LLMInput.Message) {
            messages.append(message)
        }
    }
}

extension FileDownloader.Source {
    var id: String {
        switch self {
        case .huggingFace(let id, _):
            return id
        @unknown default:
            fatalError("Unknown source type: \(self)")
        }
    }
}

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
            downloader = FileDownloader(
                source: source,
                configuration: .background(withIdentifier: "localllmclient.llmsession.\(source.id)")
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
