import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import LocalLLMClientUtility

/// Mock URLProtocol for testing download functionality without actual network requests
final class MockURLProtocol: URLProtocol {
    /// Dictionary to store mock responses by URL
    static let mockResponses: Locked<[URL: (data: Data, response: HTTPURLResponse, error: Error?)]> = .init([:])

    /// Storage for downloaded files
    static let downloadedFiles: Locked<[URL: URL]> = .init([:])

    /// Registers a mock response for a specific URL
    static func setResponse(for url: URL, with data: Data, statusCode: Int = 200, error: Error? = nil) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Length": "\(data.count)"]
        )!
        mockResponses.withLock {
            $0[url] = (data, response, error)
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
        guard let url = request.url, let client else {
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

        // Report download progress
        let totalBytes = mockData.data.count
        let chunkSize = totalBytes / 10

        var offset = 0
        while offset < totalBytes {
            // Create a chunk of data to simulate progressive loading
            let currentChunkSize = min(chunkSize, totalBytes - offset)
            let startIndex = offset
            let endIndex = offset + currentChunkSize
            let chunkData = mockData.data[startIndex..<endIndex]
            client.urlProtocol(self, didLoad: chunkData)
            offset += currentChunkSize
        }

        client.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // No action needed
    }
}
