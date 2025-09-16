import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import LocalLLMClientUtility

/// Mock URLProtocol for testing download functionality without actual network requests
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    /// Dictionary to store mock responses by URL
    static let mockResponses: Locked<[URL: (data: Data, response: HTTPURLResponse, error: Error?, delay: TimeInterval?, failHead: Bool)]> = .init([:])

    /// Storage for downloaded files
    static let downloadedFiles: Locked<[URL: URL]> = .init([:])
    
    /// Storage for cancelled tasks
    private static let cancelledTasks: Locked<Set<UUID>> = .init([])
    
    /// Unique identifier for this instance
    private let taskID = UUID()

    /// Registers a mock response for a specific URL
    static func setResponse(for url: URL, with data: Data, statusCode: Int = 200, error: Error? = nil, delay: TimeInterval? = nil, failHead: Bool = false) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Length": "\(data.count)"]
        )!
        mockResponses.withLock {
            $0[url] = (data, response, error, delay, failHead)
        }
    }

    /// Unregisters a mock response for a specific URL
    /// - Parameter url: The URL for which to remove the mock response
    static func removeResponse(for url: URL) {
        mockResponses.withLock { $0.removeValue(forKey: url) }
        downloadedFiles.withLock { $0.removeValue(forKey: url) }
    }

    // MARK: - URLProtocol methods

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard
            let url = request.url?.absoluteString.removingPercentEncoding.flatMap(URL.init),
            let client else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        guard let mockData = MockURLProtocol.mockResponses.withLock({ $0[url] }) else {
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorUnsupportedURL, userInfo: nil)
            client.urlProtocol(self, didFailWithError: error)
            return
        }

        // Send mock response data
        client.urlProtocol(self, didReceive: mockData.response, cacheStoragePolicy: .notAllowed)

        if let error = mockData.error {
            client.urlProtocol(self, didFailWithError: error)
            return
        }

        // Handle HEAD requests - only send headers, no body
        if request.httpMethod == "HEAD" {
            // If failHead is true, fail the HEAD request
            if mockData.failHead {
                let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorUnsupportedURL, userInfo: nil)
                client.urlProtocol(self, didFailWithError: error)
            } else {
                client.urlProtocolDidFinishLoading(self)
            }
            return
        }

        // For download tasks, we need to create a temporary file
        let tempFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
        try? mockData.data.write(to: tempFileURL)
        MockURLProtocol.downloadedFiles.withLock {
            $0[url] = tempFileURL
        }

        // Report download progress with optional delay
        let totalBytes = mockData.data.count
        let chunkSize = max(1, totalBytes / 100)

        if let delay = mockData.delay {
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self, weak client] in
                guard let self, let client else { return }
                // Check if task was cancelled during delay
                guard !Self.cancelledTasks.withLock({ $0.contains(self.taskID) }) else { return }
                self.sendDataInChunks(data: mockData.data, chunkSize: chunkSize, client: client, withDelay: true)
            }
        } else {
            sendDataInChunks(data: mockData.data, chunkSize: chunkSize, client: client, withDelay: false)
        }
    }

    override func stopLoading() {
        // Mark task as cancelled
        Self.cancelledTasks.withLock { $0.insert(taskID) }
        
        // Notify client that the load was cancelled
        client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
    }
    
    private func sendDataInChunks(data: Data, chunkSize: Int, client: URLProtocolClient, withDelay: Bool) {
        let id = taskID
        let totalBytes = data.count

        @Sendable func sendNextChunk(offset: Int) {
            // Check if task has been cancelled
            guard !Self.cancelledTasks.withLock({ $0.contains(id) }) else {
                return
            }
            
            guard offset < totalBytes else {
                Self.cancelledTasks.withLock { $0.remove(id) }
                client.urlProtocolDidFinishLoading(self)
                return
            }
            
            let currentChunkSize = min(chunkSize, totalBytes - offset)
            let startIndex = offset
            let endIndex = offset + currentChunkSize
            let chunkData = data[startIndex..<endIndex]
            
            client.urlProtocol(self, didLoad: chunkData)
            let offset = offset + currentChunkSize

            if withDelay && offset < totalBytes {
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                    sendNextChunk(offset: offset)
                }
            } else {
                sendNextChunk(offset: offset)
            }
        }
        
        sendNextChunk(offset: 0)
    }
}
