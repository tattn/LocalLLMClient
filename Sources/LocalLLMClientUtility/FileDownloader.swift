@preconcurrency import Hub
import Foundation

public actor FileDownloader {
    private let source: Source
    private let destination: URL

#if os(macOS)
    public static let defaultRootDestination = URL.downloadsDirectory.appending(path: "localllmclient")
#else
    public static let defaultRootDestination = URL.cachesDirectory.appending(path: "localllmclient")
#endif

    public enum Source: Sendable {
        case huggingFace(id: String, globs: HuggingFaceGlobs)

        public struct HuggingFaceGlobs: Sendable {
            public let rawValue: [String]

            public init(_ globs: [String]) {
                self.rawValue = globs
            }

            public static let mlx = HuggingFaceGlobs(["*.safetensors", "*.json"])
        }
    }

    public init(source: Source, destination: URL = defaultRootDestination) {
        self.source = source
        self.destination = destination
    }

    public func download(onProgress: @Sendable @escaping (Double) -> Void) async throws -> URL {
        switch source {
        case let .huggingFace(id, globs):
            let hub = HubApi(downloadBase: destination.appending(component: "huggingface"), useOfflineMode: false)
            let repo = Hub.Repo(id: id)
            return try await hub.snapshot(from: repo, matching: globs.rawValue) { progress in
                onProgress(progress.fractionCompleted)
            }
        }
    }
}
