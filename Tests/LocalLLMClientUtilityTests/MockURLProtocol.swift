import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import LocalLLMClientUtility

/// Mock URLProtocol for testing download functionality without actual network requests
final class MockURLProtocol: URLProtocol {
    /// Dictionary to store mock responses by URL
    static let mockResponses: Locked<[URL: (data: Data, response: HTTPURLResponse, error: Error?, delay: TimeInterval?)]> = .init([:])

    /// Storage for downloaded files
    static let downloadedFiles: Locked<[URL: URL]> = .init([:])

    /// Registers a mock response for a specific URL
    static func setResponse(for url: URL, with data: Data, statusCode: Int = 200, error: Error? = nil, delay: TimeInterval? = nil) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Length": "\(data.count)"]
        )!
        mockResponses.withLock {
            $0[url] = (data, response, error, delay)
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

        // For download tasks, we need to create a temporary file
        let tempFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
        try? mockData.data.write(to: tempFileURL)
        MockURLProtocol.downloadedFiles.withLock {
            $0[url] = tempFileURL
        }

        // Report download progress with optional delay
        let totalBytes = mockData.data.count
        let chunkSize = max(1, totalBytes / 10)
        
        if let delay = mockData.delay {
            // Use dispatch queue for delay to avoid concurrency issues
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self, weak client] in
                guard let self = self, let client = client else { return }
                self.sendDataInChunks(data: mockData.data, chunkSize: chunkSize, client: client, withDelay: true)
            }
        } else {
            sendDataInChunks(data: mockData.data, chunkSize: chunkSize, client: client, withDelay: false)
        }
    }

    override func stopLoading() {
        // No action needed
    }
    
    private func sendDataInChunks(data: Data, chunkSize: Int, client: URLProtocolClient, withDelay: Bool) {
        var offset = 0
        let totalBytes = data.count
        
        func sendNextChunk() {
            guard offset < totalBytes else {
                client.urlProtocolDidFinishLoading(self)
                return
            }
            
            let currentChunkSize = min(chunkSize, totalBytes - offset)
            let startIndex = offset
            let endIndex = offset + currentChunkSize
            let chunkData = data[startIndex..<endIndex]
            
            client.urlProtocol(self, didLoad: chunkData)
            offset += currentChunkSize
            
            if withDelay && offset < totalBytes {
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                    sendNextChunk()
                }
            } else {
                sendNextChunk()
            }
        }
        
        sendNextChunk()
    }
}
