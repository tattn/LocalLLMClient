#if os(iOS) || os(macOS)
@preconcurrency import Hub
import Foundation
import os.lock

/// An actor responsible for managing the download of files in the background.
///
/// This class conforms to `FileDownloadable` and utilizes `URLSession` with background configurations
/// to download files, primarily from Hugging Face Hub, and store them locally.
/// It supports progress observation and can resume existing downloads.
public final actor BackgroundFileDownloader: FileDownloadable {
    /// The source from which the file(s) are being downloaded (e.g., a Hugging Face repository).
    public let source: FileDownloader.Source
    private let rootDestination: URL
    private let downloader = Downloader()

    /// The default root directory where downloaded files are stored.
    /// This is typically a subdirectory within the application's support directory.
    public static let defaultRootDestination = URL.defaultRootDirectory

    /// The specific destination URL for the downloaded file(s), derived from the `source` and `rootDestination`.
    public nonisolated var destination: URL {
        source.destination(for: rootDestination)
    }

    public nonisolated var isDownloaded: Bool {
        source.isDownloaded(for: destination)
    }

    /// Initializes a new background file downloader.
    ///
    /// - Parameters:
    ///   - source: The source from which to download the file(s), e.g., a Hugging Face repository.
    ///   - destination: The root URL where the downloaded files should be stored. Defaults to `defaultRootDestination`.
    public init(source: FileDownloader.Source, destination: URL = defaultRootDestination) {
        self.source = source
        self.rootDestination = destination
        switch source {
        case let .huggingFace(id, _):
            guard let meta = try? FilesMetadata.load(from: destination) else {
                return
            }
            downloader.configureForHuggingFace(id: id, destination: source.destination(for: rootDestination), meta: meta)
        }
    }

    /// Starts or resumes the download of the file(s) from the specified source.
    ///
    /// If the files are already downloaded, this method completes immediately, calling the progress handler with `1.0`.
    /// It handles saving metadata and setting up individual downloaders for each file part if necessary.
    ///
    /// - Parameter onProgress: An optional asynchronous closure that is called with the download progress (a `Double` between 0.0 and 1.0).
    /// - Throws: An error if fetching metadata fails or if there's an issue setting up the download tasks.
    public func download(onProgress: (@Sendable (Double) async -> Void)? = nil) async throws {
        switch source {
        case let .huggingFace(id, _):
            guard !source.isDownloaded(for: destination) else {
                if let onProgress {
                    Task {
                        await onProgress(1.0)
                    }
                } else {
                    downloader.progress.completedUnitCount = downloader.progress.totalUnitCount
                }
                return
            }

            let meta = try await source.saveMetadata(to: destination)

            if let onProgress {
                downloader.setObserver { await onProgress($0.fractionCompleted) }
            }
            guard !downloader.isDownloading else {
                return
            }
            if downloader.downloaders.isEmpty {
                downloader.configureForHuggingFace(id: id, destination: source.destination(for: rootDestination), meta: meta)
            }
            downloader.download()
        }
    }

    /// Sets an observer action to be called when the download progress changes.
    ///
    /// - Parameter action: An asynchronous closure that takes a `Double` representing the fraction completed (0.0 to 1.0) and is called whenever the progress updates.
    public func setObserver(_ action: @Sendable @escaping (Double) async -> Void) {
        downloader.setObserver { await action($0.fractionCompleted) }
    }

    /// A Boolean value indicating whether any files managed by this downloader are currently being downloaded.
    public var isDownloading: Bool {
        downloader.isDownloading
    }
}

private extension Downloader {
    func configureForHuggingFace(id: String, destination: URL, meta: FilesMetadata) {
        let repo = Hub.Repo(id: id)
        let baseURL = URL(string: "https://huggingface.co")!
            .appending(component: repo.type == .models ? "" : repo.type.rawValue)
            .appending(path: repo.id)
            .appending(path: "resolve/main")

        meta.files.map(\.name)
            .filter { !FileManager.default.fileExists(atPath: destination.appending(path: $0).path) }
            .forEach {
                let url = baseURL.appending(path: $0)
                let configuration = URLSessionConfiguration.background(withIdentifier: "\(url.absoluteString)_locallmclient")
                configuration.isDiscretionary = true
                configuration.sessionSendsLaunchEvents = true
                add(.init(
                    url: url,
                    destinationURL: destination.appending(path: $0),
                    configuration: configuration
                ))
            }
    }
}

#endif
