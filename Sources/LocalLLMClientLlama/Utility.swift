#if BUILD_DOCC
@preconcurrency @_implementationOnly import llama
#else
@preconcurrency private import llama
#endif
import OSLog

// MARK: - Global State

nonisolated(unsafe) private var isLlamaInitialized = false
nonisolated(unsafe) private var isCustomLogEnabled = false
nonisolated(unsafe) private var llamaLogCallback: ((LlamaLogLevel, String) -> Void)?

// MARK: - Life Cycle

public func initializeLlama() {
    guard !isLlamaInitialized else { return }
    isLlamaInitialized = true
    llama_backend_init()

    if !isCustomLogEnabled {
#if DEBUG
        setLlamaVerbose(true)
#else
        setLlamaVerbose(false)
#endif
    }
}

public func shutdownLlama() {
    guard isLlamaInitialized else { return }
    llama_backend_free()
}

// MARK: - Logging

package extension Logger {
    static let localllm = Logger(subsystem: "com.github.tattn.LocalLLMClient", category: "localllm")
}

public func setLlamaLog(callback: ((LlamaLogLevel, String) -> Void)?) {
    llamaLogCallback = callback
    isCustomLogEnabled = true

    llama_log_set({ level, text, _ in
        guard let llamaLogCallback else { return }
        let level = LlamaLogLevel(rawValue: level.rawValue) ?? .none
        llamaLogCallback(level, text.map(String.init(cString:)) ?? "")
    }, nil)
}

public func setLlamaVerbose(_ verbose: Bool) {
    setLlamaLog(callback: verbose ? { level, message in
        llamaLog(level: level, message: message)
    } : nil)
}

package func llamaLog(level: LlamaLogLevel, message: String) {
    switch level {
    case .none:
        Logger.localllm.log("\(message)")
    case .debug, .continue:
        Logger.localllm.debug("\(message)")
    case .info:
        Logger.localllm.info("\(message)")
    case .warn:
        Logger.localllm.warning("\(message)")
    case .error:
        Logger.localllm.fault("\(message)")
    }
}

public enum LlamaLogLevel: ggml_log_level.RawValue, Sendable {
    case none, debug, info, warn, error, `continue`
}
