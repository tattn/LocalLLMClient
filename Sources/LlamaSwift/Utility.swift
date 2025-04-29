@preconcurrency import llama

nonisolated(unsafe) private var isLlamaInitialized = false

public func initializeLlama() {
    guard !isLlamaInitialized else { return }
    isLlamaInitialized = true
    llama_backend_init()
}

public func shutdownLlama() {
    guard isLlamaInitialized else { return }
    llama_backend_free()
}
