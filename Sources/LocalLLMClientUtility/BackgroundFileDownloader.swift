@preconcurrency import Hub
import Synchronization
import Foundation

public final actor BackgroundFileDownloader {
    private let source: FileDownloader.Source
    private let destination: URL
    private let downloader = BackgroundDownloader()
    public private(set) var status = Status.preparing

    public static let defaultRootDestination = URL.defaultRootDirectory

    public enum Status {
        case preparing
        case prepared
        case error(Error)
    }

    public init(source: FileDownloader.Source, destination: URL = defaultRootDestination) {
        self.source = source
        self.destination = destination
        switch source {
        case let .huggingFace(id, globs):
            Task {
                await setUpDownloaderForHuggingFace(id: id, globs: globs.rawValue)
            }
        }
    }

    public func download(onProgress: (@Sendable (Double) -> Void)? = nil) {
        Task {
            await waitUntilPrepared()
            switch source {
            case .huggingFace:
                guard !downloader.isDownloaded else {
                    if let onProgress {
                        onProgress(1.0)
                    } else {
                        downloader.progress.completedUnitCount = downloader.progress.totalUnitCount
                    }
                    return
                }
                if let onProgress {
                    downloader.setObserver(onProgress)
                }
                guard !downloader.isDownloading else {
                    return
                }
                downloader.download()
            }
        }
    }

    public func setObserver(_ action: @Sendable @escaping (Double) -> Void) {
        downloader.setObserver(action)
    }

    public var isDownloading: Bool {
        get async {
            await waitUntilPrepared()
            return downloader.isDownloading
        }
    }

    public var isDownloaded: Bool {
        get async {
            await waitUntilPrepared()
            return downloader.isDownloaded
        }
    }

    private func waitUntilPrepared() async {
        while case .preparing = status {
            try? await Task.sleep(for: .seconds(0.1))
        }
    }

    private func setUpDownloaderForHuggingFace(id: String, globs: [String]) async {
        do {
            let repo = Hub.Repo(id: id)
            let hub = HubApi.make(destination: destination, offlineMode: false)
            let filenames = try await hub.getFilenames(from: repo, matching: globs)

            let baseURL = URL(string: "https://huggingface.co")!
                .appending(component: repo.type == .models ? "" : repo.type.rawValue)
                .appending(path: repo.id)
                .appending(path: "resolve/main")

            for filename in filenames {
                let downloader = await BackgroundDownloader.Downloader(
                    url: baseURL.appending(path: filename),
                    destinationURL: hub.localRepoLocation(repo).appending(path: filename)
                )
                self.downloader.add(downloader)
            }

            status = .prepared
        } catch {
            status = .error(error)
        }
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

    func setObserver(_ action: @Sendable @escaping (Double) -> Void) {
        observer = progress.observe(\.fractionCompleted, options: [.initial, .new]) { _, change in
            guard let fractionCompleted = change.newValue else { return }
            action(fractionCompleted)
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

        public init(url: URL, destinationURL: URL) async {
            self.url = url
            self.destinationURL = destinationURL

            let config = URLSessionConfiguration.background(withIdentifier: "\(url.absoluteString)_locallmclient")
            config.isDiscretionary = true
            config.sessionSendsLaunchEvents = true
            session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

            for task in await session.allTasks {
                if task.taskDescription == destinationURL.absoluteString {
                    download(existingTask: task)
                } else {
                    task.cancel()
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
        let isDownloading: Mutex<Bool> = .init(false)



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
