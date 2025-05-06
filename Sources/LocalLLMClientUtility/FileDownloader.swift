@preconcurrency import Hub
import Foundation

public struct FileDownloader {
    private let source: Source
    private let destination: URL

    public static let defaultRootDestination = URL.defaultRootDirectory

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

    public func download(onProgress: @Sendable @escaping (Double) -> Void = { _ in }) async throws -> URL {
        if let cachedURL = await cachedURL() {
            return cachedURL
        }
        switch source {
        case let .huggingFace(id, globs):
            let repo = Hub.Repo(id: id)
            return try await HubApi.make(destination: destination, offlineMode: false).snapshot(from: repo, matching: globs.rawValue) {
                onProgress($0.fractionCompleted)
            }
        }
    }

    public func isDownloaded() async -> Bool {
        await cachedURL() != nil
    }

    public func cachedURL() async -> URL? {
        do {
            switch source {
            case let .huggingFace(id, globs):
                // TODO: Currently, not a perfect solution.
                let hub = HubApi.make(destination: destination, offlineMode: true)
                let repo = Hub.Repo(id: id)
                let filenames = try FileManager.default
                    .getFileUrls(at: hub.localRepoLocation(repo))
                    .map(\.lastPathComponent)
                let matched = globs.rawValue.reduce(into: Set<String>()) { partialResult, glob in
                    partialResult.formUnion(filenames.matching(glob: glob))
                }
                if filenames.count == matched.count {
                    return try await hub.snapshot(from: repo, matching: globs.rawValue)
                } else {
                    return nil
                }
            }
        } catch {
            return nil
        }
    }
}

extension FileDownloader.Source.HuggingFaceGlobs: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: String...) {
        self.init(elements)
    }
}

extension HubApi {
    static func make(destination: URL, offlineMode: Bool) -> HubApi {
        HubApi(
            downloadBase: destination.appending(component: "huggingface"),
            useOfflineMode: offlineMode
        )
    }
}
