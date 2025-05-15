@preconcurrency import Hub
import Foundation
import os.lock

public final actor BackgroundFileDownloader: FileDownloadable {
    public let source: FileDownloader.Source
    private let rootDestination: URL
    private let downloader = BackgroundDownloader()

    public static let defaultRootDestination = URL.defaultRootDirectory

    public nonisolated var destination: URL {
        source.destination(for: rootDestination)
    }

    public nonisolated var isDownloaded: Bool {
        source.isDownloaded(for: destination)
    }

    public init(source: FileDownloader.Source, destination: URL = defaultRootDestination) {
        self.source = source
        self.rootDestination = destination
        switch source {
        case let .huggingFace(id, _):
            guard let meta = try? FilesMetadata.load(from: destination) else {
                return
            }
            for downloader in makeDownloaders(id: id, destination: source.destination(for: rootDestination), meta: meta) {
                self.downloader.add(downloader)
            }
        }
    }

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
                downloader.setObserver(onProgress)
            }
            guard !downloader.isDownloading else {
                return
            }
            if downloader.downloaders.isEmpty {
                for downloader in makeDownloaders(id: id, destination: source.destination(for: rootDestination), meta: meta) {
                    self.downloader.add(downloader)
                }
            }
            downloader.download()
        }
    }

    public func setObserver(_ action: @Sendable @escaping (Double) async -> Void) {
        downloader.setObserver(action)
    }

    public var isDownloading: Bool {
        downloader.isDownloading
    }
}

private func makeDownloaders(id: String, destination: URL, meta: FilesMetadata) -> [BackgroundDownloader.Downloader] {
    let repo = Hub.Repo(id: id)
    let baseURL = URL(string: "https://huggingface.co")!
        .appending(component: repo.type == .models ? "" : repo.type.rawValue)
        .appending(path: repo.id)
        .appending(path: "resolve/main")

    return meta.files.map { file in
        BackgroundDownloader.Downloader(
            url: baseURL.appending(path: file.name),
            destinationURL: destination.appending(path: file.name)
        )
    }
}

final class BackgroundDownloader {
    private(set) var downloaders: [Downloader] = []
    let progress = Progress()
    private var observer: NSKeyValueObservation?

    var isDownloading: Bool {
        downloaders.contains(where: \.isDownloading)
    }

    var isDownloaded: Bool {
        downloaders.allSatisfy(\.isDownloaded)
    }

    init() {}

    func add(_ downloader: Downloader) {
        downloaders.append(downloader)
        progress.addChild(downloader.progress, withPendingUnitCount: 1)
        progress.totalUnitCount += 1
    }

    func setObserver(_ action: @Sendable @escaping (Double) async -> Void) {
        observer = progress.observe(\.fractionCompleted, options: [.initial, .new]) { _, change in
            guard let fractionCompleted = change.newValue else { return }
            Task {
                await action(fractionCompleted)
            }
        }
    }

    func download() {
        for downloader in downloaders {
            downloader.download()
        }
    }
}

extension BackgroundDownloader {
    final class Downloader: Sendable {
        private let url: URL
        private let destinationURL: URL
        private let session: URLSession
        private let delegate = Delegate()

        var progress: Progress {
            delegate.progress
        }

        var isDownloading: Bool {
            delegate.isDownloading.withLock(\.self)
        }

        var isDownloaded: Bool {
            FileManager.default.fileExists(atPath: destinationURL.path)
        }

        public init(url: URL, destinationURL: URL) {
            self.url = url
            self.destinationURL = destinationURL

            let config = URLSessionConfiguration.background(withIdentifier: "\(url.absoluteString)_locallmclient")
            config.isDiscretionary = true
            config.sessionSendsLaunchEvents = true
            session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

            Task {
                for task in await session.allTasks {
                    if task.taskDescription == destinationURL.absoluteString {
                        download(existingTask: task)
                    } else {
                        task.cancel()
                    }
                }
            }
        }

        public func download(existingTask: URLSessionTask? = nil) {
            guard !isDownloading else { return }
            delegate.isDownloading.withLock { $0 = true }

            try? FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let task = existingTask ?? session.downloadTask(with: url)
            task.taskDescription = destinationURL.absoluteString
            task.resume()
        }
    }
}

extension BackgroundDownloader.Downloader {
    final class Delegate: NSObject, URLSessionDownloadDelegate {
        let progress = Progress(totalUnitCount: 1)
        let isDownloading = OSAllocatedUnfairLock(initialState: false)

        func urlSession(
            _ session: URLSession, downloadTask: URLSessionDownloadTask,
            didFinishDownloadingTo location: URL
        ) {
#if DEBUG
            print("Download finished to location: \(location.path)")
#endif

            // Move the downloaded file to the permanent location
            guard let taskDescription = downloadTask.taskDescription,
                  let destinationURL = URL(string: taskDescription) else {
                return
            }
            try? FileManager.default.removeItem(at: destinationURL)
            do {
                try FileManager.default.moveItem(at: location, to: destinationURL)
            } catch {
                print("The URLSessionTask may be old. The app container was already invalid: \(error.localizedDescription)")
            }
        }

        func urlSession(
            _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?
        ) {
#if DEBUG
            if let error {
                print("Download failed with error: \(error.localizedDescription)")
            }
#endif
            isDownloading.withLock { $0 = false }
        }

        func urlSession(
            _ session: URLSession, downloadTask: URLSessionDownloadTask,
            didWriteData bytesWritten: Int64,
            totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
        ) {
            if bytesWritten == totalBytesWritten {
                progress.totalUnitCount = totalBytesExpectedToWrite
            }
            progress.completedUnitCount = totalBytesWritten
        }
    }
}
