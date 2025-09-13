import Foundation

/// A protocol defining the requirements for an entity that can download files.
///
/// Types conforming to `FileDownloadable` are expected to manage the source and destination
/// of downloadable files, check their download status, and handle associated metadata.
public protocol FileDownloadable: Sendable {
    /// The source from which the file(s) are downloaded (e.g., a specific Hugging Face repository).
    var source: FileDownloader.Source { get }
    /// The local URL where the downloaded file(s) are or will be stored.
    var destination: URL { get }
    /// A Boolean value indicating whether the file(s) from the source have been successfully downloaded to the destination.
    var isDownloaded: Bool { get }

    /// Removes any metadata associated with the downloaded files.
    ///
    /// This is useful for clearing up stored information about the files, potentially
    /// forcing a re-download or re-check of metadata in the future.
    ///
    /// - Throws: An error if the metadata cannot be removed, for example, due to file permission issues or if the metadata file doesn't exist.
    func removeMetadata() throws
}

/// A struct that implements the `FileDownloadable` protocol to manage file downloads.
///
/// This struct provides a concrete implementation for downloading files, particularly from
/// Hugging Face Hub, using the `HubApi`. It handles metadata storage and progress reporting.
public struct FileDownloader: FileDownloadable {
    public let source: Source
    private let rootDestination: URL
    private let downloadConfiguration: DownloadConfiguration

    /// The default root directory where downloaded files are stored.
    /// This is typically a subdirectory within the application's support directory, named "LocalLLM".
    public static let defaultRootDestination = URL.defaultRootDirectory

    public var destination: URL {
        source.destination(for: rootDestination)
    }

    public var isDownloaded: Bool {
        source.isDownloaded(for: destination)
    }

    /// Specifies the source from which files are to be downloaded.
    public enum Source: Sendable, Equatable {
        /// Represents a source from Hugging Face Hub.
        ///
        /// - Parameters:
        ///   - id: The repository identifier on Hugging Face (e.g., "ml-explore/mlx-swift-examples").
        ///   - globs: A set of glob patterns to filter which files are downloaded from the repository.
        case huggingFace(id: String, globs: Globs)

        package func destination(for rootDestination: URL) -> URL {
            switch self {
            case let .huggingFace(id, _):
                let client = HuggingFaceAPI(repo: .init(id: id))
                return client.getLocalRepoLocation(downloadBase: rootDestination)
            }
        }

        func isDownloaded(for destination: URL) -> Bool {
            guard FileManager.default.fileExists(atPath: destination.path),
                  let meta = try? FilesMetadata.load(from: destination) else {
                return false
            }

            // Check if all files in metadata exist in the destination directory
            let fileURLs = FileManager.default.enumerator(at: destination, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL } ?? []
            let filesOnDisk = Dictionary(uniqueKeysWithValues: fileURLs.map { ($0.lastPathComponent, $0) })

            return meta.files.allSatisfy { file in
                guard let fileURL = filesOnDisk[file.name] else {
                    return false
                }

                // Check if it matches the file size
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    let fileSize = attributes[.size] as? Int ?? 0
                    return fileSize == file.size
                } catch {
                    return false
                }
            }
        }

        func downloadFiles(to rootDestination: URL, configuration: HuggingFaceAPI.DownloadConfiguration = .default, onProgress: @Sendable @escaping (Double) async -> Void) async throws {
            switch self {
            case let .huggingFace(id, globs):
                let client = HuggingFaceAPI(repo: .init(id: id))
                try await client.downloadSnapshot(to: rootDestination, matching: globs, configuration: configuration) { progress in
                    Task { [progress] in
                        await onProgress(progress.fractionCompleted)
                    }
                }
            }
        }

        @discardableResult
        func saveMetadata(to destination: URL) async throws -> FilesMetadata {
            switch self {
            case let .huggingFace(id, globs):
                let client = HuggingFaceAPI(repo: .init(id: id))
                let fileInfos = try await client.getFileInfo(matching: globs)
                let metadata = FilesMetadata(files: fileInfos.map { FilesMetadata.FileMetadata(name: $0.filename, size: $0.size) })
                try metadata.save(to: destination)
                return metadata
            }
        }

        func removeMetadata(from destination: URL) throws {
            try FileManager.default.removeItem(at: destination.appendingPathComponent(FilesMetadata.filename))
        }
    }

    public struct DownloadConfiguration: Sendable {
        public var identifier: String?
        public var protocolClasses: [AnyClass]?

        /// Initializes a new download configuration
        public static let `default` = DownloadConfiguration(identifier: nil)

        /// Creates a new download configuration for background downloads
        public static func background(withIdentifier identifier: String) -> DownloadConfiguration {
            DownloadConfiguration(identifier: identifier)
        }

        func makeHuggingFaceConfiguration() -> HuggingFaceAPI.DownloadConfiguration {
            var result: HuggingFaceAPI.DownloadConfiguration = if let identifier {
                .background(withIdentifier: identifier)
            } else {
                .default
            }
            result.protocolClasses = protocolClasses
            return result
        }
    }

    /// Initializes a new file downloader.
    ///
    /// - Parameters:
    ///   - source: The source from which to download the file(s), e.g., a Hugging Face repository.
    ///   - destination: The root URL where the downloaded files should be stored. Defaults to `defaultRootDestination`.
    public init(source: Source, destination: URL = defaultRootDestination) {
        self.source = source
        self.rootDestination = destination
        self.downloadConfiguration = .default
    }
    
    /// Initializes a new file downloader with a custom download configuration.
    ///
    /// - Parameters:
    ///   - source: The source from which to download the file(s), e.g., a Hugging Face repository.
    ///   - destination: The root URL where the downloaded files should be stored. Defaults to `defaultRootDestination`.
    ///   - configuration: The download configuration to use, which can include background download settings.
    public init(source: Source, destination: URL = defaultRootDestination, configuration: DownloadConfiguration) {
        self.source = source
        self.rootDestination = destination
        self.downloadConfiguration = configuration
    }

    /// Starts the download of the file(s) from the specified source.
    ///
    /// If the files are already downloaded, this method completes immediately, calling the progress handler with `1.0`.
    /// It handles saving metadata and then uses `HubApi` to perform the actual download, reporting progress via the `onProgress` closure.
    ///
    /// - Parameter onProgress: An asynchronous closure that is called with the download progress (a `Double` between 0.0 and 1.0). Defaults to an empty closure.
    /// - Throws: An error if saving metadata fails or if the `HubApi` encounters an issue during the download.
    public func download(onProgress: @Sendable @escaping (Double) async -> Void = { _ in }) async throws {
        let destination = self.destination
        guard !source.isDownloaded(for: destination) else {
            await onProgress(1.0)
            return
        }
        try await source.saveMetadata(to: destination)
        try await source.downloadFiles(
            to: rootDestination,
            configuration: downloadConfiguration.makeHuggingFaceConfiguration(),
            onProgress: onProgress
        )
    }
}

struct FilesMetadata: Codable, Sendable {
    static let filename = ".filesmeta"

    let files: [FileMetadata]

    struct FileMetadata: Codable, Sendable {
        let name: String
        let size: Int
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
