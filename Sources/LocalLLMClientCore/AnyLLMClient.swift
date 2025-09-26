import Foundation

/// Type-erased LLM client
public struct AnyLLMClient: LLMClient {
    private let _generateText: @Sendable (LLMInput) async throws -> String
    private let _textStream: @Sendable (LLMInput) async throws -> AsyncThrowingStream<String, Error>
    private let _generateToolCalls: @Sendable (LLMInput) async throws -> GeneratedContent
    private let _resume: @Sendable ([LLMToolCall], [(String, String)], LLMInput) async throws -> String
    private let _resumeStream: @Sendable ([LLMToolCall], [(String, String)], LLMInput) async throws -> AsyncThrowingStream<StreamingChunk, any Error>
    private let _responseStream: @Sendable (LLMInput) async throws -> AsyncThrowingStream<StreamingChunk, Error>
    private let _pauseGeneration: @Sendable () async -> Void
    private let _resumeGeneration: @Sendable () async -> Void
    private let _isGenerationPaused: @Sendable () async -> Bool
    
    /// Creates a type-erased wrapper for any LLMClient
    public init<C: LLMClient>(_ client: C) {
        self._generateText = { input in
            try await client.generateText(from: input)
        }
        self._textStream = { input in
            Self.createAsyncStream { continuation in
                for try await text in try await client.textStream(from: input) {
                    continuation.yield(text)
                }
            }
        }
        self._generateToolCalls = { input in
            try await client.generateToolCalls(from: input)
        }
        self._resume = { toolCalls, toolOutputs, originalInput in
            try await client.resume(
                withToolCalls: toolCalls,
                toolOutputs: toolOutputs,
                originalInput: originalInput
            )
        }
        self._resumeStream = { toolCalls, toolOutputs, originalInput in
            Self.createAsyncStream { continuation in
                for try await content in try await client.resumeStream(
                    withToolCalls: toolCalls,
                    toolOutputs: toolOutputs,
                    originalInput: originalInput
                ) {
                    continuation.yield(content)
                }
            }
        }
        self._responseStream = { input in
            Self.createAsyncStream { continuation in
                for try await content in try await client.responseStream(from: input) {
                    continuation.yield(content)
                }
            }
        }
        self._pauseGeneration = {
            await client.pauseGeneration()
        }
        self._resumeGeneration = {
            await client.resumeGeneration()
        }
        self._isGenerationPaused = {
            await client.isGenerationPaused
        }
    }
    
    /// Creates an AsyncThrowingStream with proper task management and error handling
    private static func createAsyncStream<T>(
        body: @Sendable @escaping (AsyncThrowingStream<T, Error>.Continuation) async throws -> Void
    ) -> AsyncThrowingStream<T, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await body(continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func generateText(from input: LLMInput) async throws -> String {
        try await _generateText(input)
    }

    public func textStream(from input: LLMInput) async throws -> AsyncThrowingStream<String, Error> {
        try await _textStream(input)
    }

    public func generateToolCalls(from input: LLMInput) async throws -> GeneratedContent {
        try await _generateToolCalls(input)
    }

    public func resume(
        withToolCalls toolCalls: [LLMToolCall],
        toolOutputs: [(String, String)],
        originalInput: LLMInput
    ) async throws -> String {
        try await _resume(toolCalls, toolOutputs, originalInput)
    }

    public func resumeStream(
        withToolCalls toolCalls: [LLMToolCall],
        toolOutputs: [(String, String)],
        originalInput: LLMInput
    ) async throws -> AsyncThrowingStream<StreamingChunk, Error> {
        try await _resumeStream(toolCalls, toolOutputs, originalInput)
    }

    public func responseStream(from input: LLMInput) async throws -> AsyncThrowingStream<StreamingChunk, Error> {
        try await _responseStream(input)
    }
    
    public func pauseGeneration() async {
        await _pauseGeneration()
    }
    
    public func resumeGeneration() async {
        await _resumeGeneration()
    }
    
    public var isGenerationPaused: Bool {
        get async {
            await _isGenerationPaused()
        }
    }
}
