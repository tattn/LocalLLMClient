import Foundation
import LocalLLMClientUtility

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
#if !os(Linux)
@Observable
#endif
public final class LLMSession: Sendable {
    public init<T: Model>(model: T, messages: [LLMInput.Message] = [], tools: [any LLMTool] = []) {
        generator = Generator(model: model, messages: messages, tools: tools.map { AnyLLMTool($0) })
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
        if generator.tools.isEmpty {
            return generator.streamResponse(to: prompt, attachments: attachments)
        } else {
            return generator.streamResponseWithAutomaticToolCalling(to: prompt, attachments: attachments)
        }
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension LLMSession {
    @_disfavoredOverload
    public convenience init(model: LLMSession.DownloadModel, messages: [LLMInput.Message] = [], tools: [any LLMTool] = []) {
        self.init(model: model, messages: messages, tools: tools)
    }

    @_disfavoredOverload
    public convenience init(model: LLMSession.SystemModel, messages: [LLMInput.Message] = [], tools: [any LLMTool] = []) {
        self.init(model: model, messages: messages, tools: tools)
    }
    
    @_disfavoredOverload
    public convenience init(model: LLMSession.LocalModel, messages: [LLMInput.Message] = [], tools: [any LLMTool] = []) {
        self.init(model: model, messages: messages, tools: tools)
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension LLMSession {
#if !os(Linux)
    @Observable
#endif
    final class Generator: Sendable {
        public nonisolated init(model: any Model, messages: [LLMInput.Message], tools: [AnyLLMTool]) {
            self.model = model
            self._messages = Locked(messages)
            self.tools = tools
        }

        let model: any Model
        let tools: [AnyLLMTool]
        private let client = Locked<AnyLLMClient?>(nil)
        private let _messages: Locked<[LLMInput.Message]>

#if os(Linux)
        var messages: [LLMInput.Message] {
            get {
                _messages.withLock(\.self)
            }
            set {
                _messages.withLock { messages in
                    messages = newValue
                }
            }
        }
#else
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
#endif

        public func prewarm() async throws {
            let client = try await loadClient()
            self.client.withLock { $0 = client }
        }

        private func loadClient() async throws -> AnyLLMClient {
            if let client = client.withLock(\.self) {
                return client
            }

            try await model.prewarm()

            let client = try await model.makeClient(tools)
            
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
        
        // Stream response with automatic tool calling
        nonisolated func streamResponseWithAutomaticToolCalling(to prompt: String, attachments: [LLMAttachment]) -> AsyncThrowingStream<String, any Error> {
            return AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        let client = try await loadClient()
                        messages.append(.user(prompt, attachments: attachments))

                        var collectedResponse = ""
                        var collectedToolCalls: [LLMToolCall] = []
                        
                        let stream = try await client.responseStream(from: .chat(messages))
                        for try await content in stream {
                            switch content {
                            case .text(let chunk):
                                collectedResponse += chunk
                                continuation.yield(chunk)
                            case .toolCall(let toolCall):
                                collectedToolCalls.append(toolCall)
                            }
                        }
                        
                        if !collectedToolCalls.isEmpty {
                            var toolCallResults: [String: Result<ToolOutput, Error>] = [:]
                            for toolCall in collectedToolCalls {
                                do {
                                    let output = try await executeToolCall(toolCall)
                                    toolCallResults[toolCall.id] = .success(output)
                                } catch {
                                    toolCallResults[toolCall.id] = .failure(error)
                                    if let tool = tools.first(where: { $0.name == toolCall.name }) {
                                        throw ToolCallError(tool: tool.underlyingTool, underlyingError: error)
                                    } else {
                                        throw error
                                    }
                                }
                            }

                            let toolOutputs = collectedToolCalls.compactMap { toolCall -> (String, String)? in
                                guard case .success(let output) = toolCallResults[toolCall.id] else { return nil }
                                let outputString = output.data.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
                                return (toolCall.id, outputString)
                            }

                            var finalResponse = ""
                            let resumeStream = try await client.resumeStream(
                                withToolCalls: collectedToolCalls,
                                toolOutputs: toolOutputs,
                                originalInput: .chat(messages)
                            )

                            for try await content in resumeStream {
                                switch content {
                                case .text(let chunk):
                                    finalResponse += chunk
                                    continuation.yield(chunk)
                                case .toolCall:
                                    // Tool calls in resume should be handled separately if needed
                                    break
                                }
                            }

                            messages.append(.assistant(finalResponse))
                        } else {
                            messages.append(.assistant(collectedResponse))
                        }
                        
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
        
        
        private func executeToolCall(_ toolCall: LLMToolCall) async throws -> ToolOutput {
            guard let tool = tools.first(where: { $0.name == toolCall.name }) else {
                throw LLMError.invalidParameter(reason: "Tool '\(toolCall.name)' not found")
            }
            
            return try await tool.call(argumentsJSON: toolCall.arguments)
        }
    }

    /// An error that occurs during tool calling.
    public struct ToolCallError: Error {
        /// The tool that caused the error.
        public let tool: any LLMTool
        /// The underlying error that occurred.
        public let underlyingError: Error
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public extension LLMSession {
    protocol Model: Sendable {
        var makeClient: @Sendable ([AnyLLMTool]) async throws -> AnyLLMClient { get }

        func prewarm() async throws
    }

    struct SystemModel: Model {
        public let prewarm: @Sendable () async throws -> Void
        public let makeClient: @Sendable ([AnyLLMTool]) async throws -> AnyLLMClient

        package init(
            prewarm: @Sendable @escaping () async throws -> Void,
            makeClient: @Sendable @escaping ([AnyLLMTool]) async throws -> AnyLLMClient
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
        public let makeClient: @Sendable ([AnyLLMTool]) async throws -> AnyLLMClient

        public var isDownloaded: Bool {
            downloader.isDownloaded
        }

        /// The local path where the model files are stored.
        public var modelPath: URL {
            downloader.destination
        }

        package init(source: FileDownloader.Source, destination: URL? = nil, makeClient: @Sendable @escaping ([AnyLLMTool]) async throws -> AnyLLMClient) {
            self.source = source
            let destination = destination ?? FileDownloader.defaultRootDestination
#if os(iOS)
            let identifier = switch source {
            case .huggingFace(let id, _):
                "localllmclient.llmsession.\(id)"
            }
            downloader = FileDownloader(
                source: source,
                destination: destination,
                configuration: .background(withIdentifier: identifier)
            )
#else
            downloader = FileDownloader(source: source, destination: destination)
#endif
            self.makeClient = makeClient
        }

        public func prewarm() async throws {
            try await downloadModel()
        }

        public func downloadModel(onProgress: @Sendable @escaping (Double) async -> Void = { _ in }) async throws {
            try await downloader.download(onProgress: onProgress)
        }

        public static func removeAllModels(
            in url: URL = FileDownloader.defaultRootDestination,
            excludingModels: [any Model] = []
        ) throws {
            let excludedURLs: [URL] = excludingModels.compactMap { model -> URL? in
                switch model {
                case let model as LLMSession.DownloadModel: model.modelPath
                case let model as LLMSession.LocalModel: model.modelPath
                default: nil
                }
            }

            try FileManager.default.removeAllItems(in: url, excludingURLs: excludedURLs)
        }
    }
    
    struct LocalModel: Model {
        public let makeClient: @Sendable ([AnyLLMTool]) async throws -> AnyLLMClient

        /// The local path of the model.
        public let modelPath: URL

        package init(modelPath: URL, makeClient: @Sendable @escaping ([AnyLLMTool]) async throws -> AnyLLMClient) {
            self.modelPath = modelPath
            self.makeClient = makeClient
        }
        
        public func prewarm() async throws {
            // No prewarming needed for local models
        }
    }
}
