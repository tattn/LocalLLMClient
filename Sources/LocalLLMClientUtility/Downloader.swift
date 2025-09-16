import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@MainActor
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
        observer = progress.observe(\.fractionCompleted, options: [.initial, .new]) { progress, _ in
            Task {
                await action(progress)
            }
        }
#endif
    }

    func download() async {
        guard !downloaders.isEmpty else {
            // Notify that download is complete
            progress.totalUnitCount = 1
            progress.completedUnitCount = 1
            return
        }
        
        // Fetch file sizes first
        var totalBytes: Int64 = 0
        await withTaskGroup(of: (ChildDownloader, Int64).self) { group in
            for downloader in downloaders where !downloader.isDownloaded {
                group.addTask {
                    let size = await downloader.fetchFileSize()
                    return (downloader, size)
                }
            }

            let defaultWeight: Int64 = 1_000_000
            for await (downloader, size) in group {
                if size > 0 {
                    totalBytes += size
                    progress.addChild(downloader.progress, withPendingUnitCount: size)
                } else {
                    // If we can't get the size, use a default weight
                    progress.addChild(downloader.progress, withPendingUnitCount: defaultWeight)
                    totalBytes += defaultWeight
                }
            }
        }

        progress.totalUnitCount = totalBytes

        // Start downloads
        for downloader in downloaders {
            downloader.download()
        }
    }

    func waitForDownloads() async throws {
        while isDownloading, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
        }
        if progress.fractionCompleted < 1.0 {
            if Task.isCancelled {
                cancelAllDownloads()
                throw CancellationError()
            } else {
                let firstError = downloaders.lazy.compactMap(\.error).first
                for downloader in downloaders {
                    downloader.reset()
                }
                if let firstError {
                    throw firstError
                }
            }
        }
    }
    
    func cancelAllDownloads() {
        for downloader in downloaders {
            downloader.cancel()
        }
        progress.cancel()
    }
}

extension Downloader {
    final class ChildDownloader: Sendable {
        private let url: URL
        private let destinationURL: URL
        private let session: Locked<URLSession>
        private let headSession: URLSession
        private let delegate = Delegate()
        private let currentTask = Locked<URLSessionTask?>(nil)

        var progress: Progress {
            delegate.progress
        }

        var isDownloading: Bool {
            delegate.state.withLock {
                if case .downloading = $0 {
                    return true
                }
                return false
            }
        }

        var isDownloaded: Bool {
            FileManager.default.fileExists(atPath: destinationURL.path)
        }

        var error: Error? {
            delegate.state.withLock {
                if case .error(let error) = $0 {
                    return error
                }
                return nil
            }
        }

        public init(url: URL, destinationURL: URL, configuration: URLSessionConfiguration = .default, headSessionConfiguration: URLSessionConfiguration = .ephemeral) {
            self.url = url
            self.destinationURL = destinationURL
            let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            self.session = Locked(session)
            self.headSession = URLSession(configuration: headSessionConfiguration)

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

        func fetchFileSize() async -> Int64 {
            // Skip if already downloaded
            if isDownloaded {
                return 0
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            
            do {
                let (_, response) = try await headSession.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"),
                   let size = Int64(contentLength) {
                    return size
                }
            } catch {
#if DEBUG
                print("Failed to fetch file size for \(url): \(error)")
#endif
            }
            return 0
        }
        
        func download(existingTask: URLSessionTask? = nil) {
            guard !isDownloading else { return }
            delegate.state.withLock { $0 = .downloading }

            try? FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            var request = URLRequest(url: url)
            // https://stackoverflow.com/questions/12235617/mbprogresshud-with-nsurlconnection/12599242#12599242
            request.addValue("", forHTTPHeaderField: "Accept-Encoding")
            let task = existingTask ?? session.withLock(\.self).downloadTask(with: request)
            task.taskDescription = destinationURL.absoluteString
            task.priority = URLSessionTask.highPriority
            currentTask.withLock { $0 = task }
            task.resume()
        }
        
        func cancel() {
            currentTask.withLock { task in
                task?.cancel()
                task = nil
            }
            delegate.state.withLock { $0 = .error(CancellationError()) }
            // Clean up partial download if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }

            reset()
        }

        func reset() {
            session.withLock {
                $0.invalidateAndCancel()
                $0 = URLSession(configuration: $0.configuration, delegate: delegate, delegateQueue: nil)
            }
        }
    }
}

extension Downloader.ChildDownloader {
    final class Delegate: NSObject, URLSessionDownloadDelegate {
        let progress = Progress(totalUnitCount: 1)
        let state = Locked(State.initial)

        enum State {
            case initial
            case downloading
            case completed
            case error(Error)
        }

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

                state.withLock { $0 = .error(error) }
            } else {
                state.withLock { $0 = .completed }
            }
        }

        func urlSession(
            _ session: URLSession, downloadTask: URLSessionDownloadTask,
            didWriteData bytesWritten: Int64,
            totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
        ) {
            if totalBytesExpectedToWrite > 0 && progress.totalUnitCount != totalBytesExpectedToWrite {
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
