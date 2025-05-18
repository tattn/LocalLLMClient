@preconcurrency import Hub
import Foundation

public protocol FileDownloadable: Sendable {
    var source: FileDownloader.Source { get }
    var destination: URL { get }
    var isDownloaded: Bool { get }

    func removeMetadata() throws
}

public struct FileDownloader: FileDownloadable {
    public let source: Source
    private let rootDestination: URL

    public static let defaultRootDestination = URL.defaultRootDirectory

    public var destination: URL {
        source.destination(for: rootDestination)
    }

    public var isDownloaded: Bool {
        source.isDownloaded(for: rootDestination)
    }

    public enum Source: Sendable {
        case huggingFace(id: String, globs: HuggingFaceGlobs)

        public struct HuggingFaceGlobs: Sendable, Equatable {
            public let rawValue: [String]

            public init(_ globs: [String]) {
                self.rawValue = globs
            }

            public static let mlx = HuggingFaceGlobs(["*.safetensors", "*.json"])
        }

        func destination(for rootDestination: URL) -> URL {
            switch self {
            case let .huggingFace(id, _):
                let hub = HubApi.make(destination: rootDestination, offlineMode: false)
                return hub.localRepoLocation(Hub.Repo(id: id))
            }
        }

        func isDownloaded(for destination: URL) -> Bool {
            guard FileManager.default.fileExists(atPath: destination.path),
                  let meta = try? FilesMetadata.load(from: destination) else {
                return false
            }

            let fileURLs = FileManager.default.enumerator(at: destination, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL } ?? []
            return meta.files.allSatisfy { file in
                fileURLs.contains { url in
                    file.name == url.lastPathComponent
                }
            }
        }

        @discardableResult
        func saveMetadata(to destination: URL) async throws -> FilesMetadata {
            switch self {
            case let .huggingFace(id, globs):
                let filenames = try await HubApi.shared.getFilenames(from: Hub.Repo(id: id), matching: globs.rawValue)
                let metadata = FilesMetadata(files: filenames.map { FilesMetadata.FileMetadata(name: $0) })
                try metadata.save(to: destination)
                return metadata
            }
        }

        func removeMetadata(from destination: URL) throws {
            try FileManager.default.removeItem(at: destination.appendingPathComponent(FilesMetadata.filename))
        }
    }

    public init(source: Source, destination: URL = defaultRootDestination) {
        self.source = source
        self.rootDestination = destination
    }

    public func download(onProgress: @Sendable @escaping (Double) async -> Void = { _ in }) async throws {
        let destination = source.destination(for: rootDestination)
        guard !source.isDownloaded(for: destination) else {
            await onProgress(1.0)
            return
        }
        try await source.saveMetadata(to: destination)

        switch source {
        case let .huggingFace(id, globs):
            let repo = Hub.Repo(id: id)
            try await HubApi.make(destination: rootDestination, offlineMode: false).snapshot(from: repo, matching: globs.rawValue) { progress in
                Task {
                    await onProgress(progress.fractionCompleted)
                }
            }
        }
    }
}

struct FilesMetadata: Codable, Sendable {
    static let filename = ".filesmeta"

    let files: [FileMetadata]

    struct FileMetadata: Codable, Sendable {
        let name: String
    }

    static func load(from url: URL) throws -> FilesMetadata {
        let data = try Data(contentsOf: url.appendingPathComponent(filename))
        return try JSONDecoder().decode(FilesMetadata.self, from: data)
    }

    func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(self)
        try data.write(to: url.appendingPathComponent(Self.filename))
    }
}

public extension FileDownloadable {
    func removeMetadata() throws {
        try source.removeMetadata(from: destination)
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
