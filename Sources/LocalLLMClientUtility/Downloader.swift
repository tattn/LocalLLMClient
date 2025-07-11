import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class Downloader {
    private(set) var downloaders: [ChildDownloader] = []
    let progress = Progress(totalUnitCount: 0)
#if os(Linux)
    private var observer: Task<Void, Never>?
#else
    private var observer: NSKeyValueObservation?
#endif

    var isDownloading: Bool {
        downloaders.contains(where: \.isDownloading)
    }

    var isDownloaded: Bool {
        downloaders.allSatisfy(\.isDownloaded)
    }

    init() {}

#if os(Linux)
    deinit {
        observer?.cancel()
    }
#endif

    func add(_ downloader: ChildDownloader) {
        downloaders.append(downloader)
        progress.addChild(downloader.progress, withPendingUnitCount: 1)
        progress.totalUnitCount += 1
    }

    func setObserver(_ action: @Sendable @escaping (Progress) async -> Void) {
#if os(Linux)
        observer?.cancel()
        observer = Task { [progress] in
            var fractionCompleted = progress.fractionCompleted
            while !Task.isCancelled {
                if fractionCompleted != progress.fractionCompleted {
                    fractionCompleted = progress.fractionCompleted
                    await action(progress)
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
#else
        observer = progress.observe(\.fractionCompleted, options: [.initial, .new]) { progress, change in
            Task {
                await action(progress)
            }
        }
#endif
    }

    func download() {
        guard !downloaders.isEmpty else {
            // Notify that download is complete
            progress.totalUnitCount = 1
            progress.completedUnitCount = 1
            return
        }
        for downloader in downloaders {
            downloader.download()
        }
    }

    func waitForDownloads() async {
        while isDownloading && progress.fractionCompleted < 1.0 {
            try? await Task.sleep(for: .seconds(1))
        }
    }
}

extension Downloader {
    final class ChildDownloader: Sendable {
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

        public init(url: URL, destinationURL: URL, configuration: URLSessionConfiguration = .default) {
            self.url = url
            self.destinationURL = destinationURL
            session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)

#if !os(Linux)
            Task {
                for task in await session.allTasks {
                    if task.taskDescription == destinationURL.absoluteString {
                        download(existingTask: task)
                    } else {
                        task.cancel()
                    }
                }
            }
#endif
        }

        public func download(existingTask: URLSessionTask? = nil) {
            guard !isDownloading else { return }
            delegate.isDownloading.withLock { $0 = true }

            try? FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            var request = URLRequest(url: url)
            // https://stackoverflow.com/questions/12235617/mbprogresshud-with-nsurlconnection/12599242#12599242
            request.addValue("", forHTTPHeaderField: "Accept-Encoding")
            let task = existingTask ?? session.downloadTask(with: request)
            task.taskDescription = destinationURL.absoluteString
            task.priority = URLSessionTask.highPriority
            task.resume()
        }
    }
}

extension Downloader.ChildDownloader {
    final class Delegate: NSObject, URLSessionDownloadDelegate {
        let progress = Progress(totalUnitCount: 1)
        let isDownloading = Locked(false)

        func urlSession(
            _ session: URLSession, downloadTask: URLSessionDownloadTask,
            didFinishDownloadingTo location: URL
        ) {
#if DEBUG
            print("Download finished to location: \(location.path)")
#endif

            // Move the downloaded file to the permanent location
            guard let destinationURL = downloadTask.destinationURL else {
                return
            }
            try? FileManager.default.removeItem(at: destinationURL)
            do {
                try FileManager.default.createDirectory(
                    at: destinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try FileManager.default.moveItem(at: location, to: destinationURL)
            } catch {
                print("The URLSessionTask may be old. The app container was already invalid: \(error.localizedDescription)")
            }
        }

        func urlSession(
            _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?
        ) {
            if let error {
#if DEBUG
                print("Download failed with error: \(error.localizedDescription)")
#endif
                if let url = task.destinationURL {
                    // Attempt to remove the file if it exists
                    try? FileManager.default.removeItem(at: url)
                }
            }
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

private extension URLSessionTask {
    var destinationURL: URL? {
        guard let taskDescription else { return nil }
        return URL(string: taskDescription)
    }
}
