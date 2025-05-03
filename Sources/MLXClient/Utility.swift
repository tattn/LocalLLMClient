import MLX

// MARK: - Global State

nonisolated(unsafe) private var isMLXInitialized = false

// MARK: - Life Cycle

public func initializeMLX() {
    guard !isMLXInitialized else { return }
    isMLXInitialized = true
    MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)
}
