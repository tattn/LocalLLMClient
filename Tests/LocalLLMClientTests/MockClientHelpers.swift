import LocalLLMClientCore

/// Helper extension for test mock clients to provide default implementations of pause-related methods
extension LLMClient {
    func pauseGeneration() async {
        // Default no-op implementation for tests
    }
    
    func resumeGeneration() async {
        // Default no-op implementation for tests
    }
    
    var isGenerationPaused: Bool {
        get async {
            false
        }
    }
}