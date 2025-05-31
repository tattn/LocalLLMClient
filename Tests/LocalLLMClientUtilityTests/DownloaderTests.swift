import Foundation
import Testing
#if canImport(FoundationNetworking)
import FoundationNetworking
let canImportFoundationNetworking = true
#else
let canImportFoundationNetworking = false
#endif
@testable import LocalLLMClientUtility

struct DownloaderTests {
    
    /// Creates a mock session configuration with MockURLProtocol
    private func mockSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return configuration
    }
    
    /// Helper function to create a temporary directory for test file downloads
    private func createTemporaryDirectory() -> URL {
        let tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "DownloaderTests_\(UUID().uuidString)",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(
            at: tempDirURL,
            withIntermediateDirectories: true
        )
        return tempDirURL
    }
    
    /// Cleanup temporary files after tests
    private func cleanupTemporaryDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    @Test
    func testDownloaderInitialization() {
        let downloader = Downloader()
        
        #expect(downloader.downloaders.isEmpty)
        #expect(downloader.progress.totalUnitCount == 0)
        #expect(!downloader.isDownloading)
        #expect(downloader.isDownloaded)
    }
    
    @Test
    func testAddChildDownloader() {
        let downloader = Downloader()
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let sourceURL = URL(string: "https://\(#function)")!
        let destinationURL = tempDir.appendingPathComponent("\(#function).txt")

        let childDownloader = Downloader.ChildDownloader(
            url: sourceURL,
            destinationURL: destinationURL,
            configuration: mockSessionConfiguration()
        )
        
        downloader.add(childDownloader)
        
        #expect(downloader.downloaders.count == 1)
        #expect(downloader.progress.totalUnitCount == 1)
    }
    
    @Test
    func testEmptyDownloadCompletes() {
        let downloader = Downloader()
        
        // Download should immediately complete when no downloaders are added
        downloader.download()
        
        #expect(downloader.progress.totalUnitCount == 1)
        #expect(downloader.progress.completedUnitCount == 1)
        #expect(!downloader.isDownloading)
        #expect(downloader.isDownloaded)
    }
    
    @Test(.disabled(if: canImportFoundationNetworking))
    func testSuccessfulDownload() async throws {
        // Prepare the mock data
        let testData = "Test file content".data(using: .utf8)!
        let sourceURL = URL(string: "https://\(#function)")!

        // Setup the mock response
        MockURLProtocol.setResponse(for: sourceURL, with: testData)
        defer {
            MockURLProtocol.removeResponse(for: sourceURL)
        }

        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appendingPathComponent("\(#function).txt")

        // Create and setup the downloader
        let downloader = Downloader()
        let childDownloader = Downloader.ChildDownloader(
            url: sourceURL,
            destinationURL: destinationURL,
            configuration: mockSessionConfiguration()
        )
        
        downloader.add(childDownloader)
        
        // Track progress updates
        var progressUpdates: [Double] = []
        downloader.setObserver { @MainActor progress in
            progressUpdates.append(progress.fractionCompleted)
        }
        
        // Start the download and wait for completion
        try await downloader.downloadAndAwait()
        
        // Verify the download completed successfully
        #expect(!downloader.isDownloading)
        #expect(downloader.isDownloaded)
        #expect(FileManager.default.fileExists(atPath: destinationURL.path))
        
        // Check if file content was correctly saved
        if let downloadedData = try? Data(contentsOf: destinationURL) {
            #expect(downloadedData == testData)
        } else {
            Issue.record("Downloaded file could not be read")
        }
        
        // Verify that progress was tracked
        #expect(!progressUpdates.isEmpty)
        #expect(progressUpdates.last == 1.0)
    }
    
    @Test(.disabled(if: canImportFoundationNetworking))
    func testDownloadWithError() async throws {
        // Prepare the mock error
        let sourceURL = URL(string: "https://\(#function)")!
        let error = NSError(domain: "com.test.downloader", code: 42, userInfo: [NSLocalizedDescriptionKey: "Mock download error"])
        
        // Setup the mock response with error
        MockURLProtocol.setResponse(for: sourceURL, with: Data(), error: error)
        defer {
            MockURLProtocol.removeResponse(for: sourceURL)
        }

        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appendingPathComponent("\(#function).txt")

        // Create and setup the downloader
        let downloader = Downloader()
        let childDownloader = Downloader.ChildDownloader(
            url: sourceURL,
            destinationURL: destinationURL,
            configuration: mockSessionConfiguration()
        )
        
        downloader.add(childDownloader)
        
        // Start the download and wait for completion
        try await downloader.downloadAndAwait()
        
        // Verify the download completed with error
        #expect(!downloader.isDownloading)
        #expect(!FileManager.default.fileExists(atPath: destinationURL.path))
    }
    
    @Test(.disabled(if: canImportFoundationNetworking))
    func testMultipleDownloads() async throws {
        // Prepare mock data for multiple files
        let file1URL = URL(string: "https://\(#function)/file1.txt")!
        let file1Data = "File 1 content".data(using: .utf8)!
        
        let file2URL = URL(string: "https://\(#function)/file2.txt")!
        let file2Data = "File 2 content".data(using: .utf8)!
        
        // Setup mock responses
        MockURLProtocol.setResponse(for: file1URL, with: file1Data)
        MockURLProtocol.setResponse(for: file2URL, with: file2Data)
        defer {
            MockURLProtocol.removeResponse(for: file1URL)
            MockURLProtocol.removeResponse(for: file2URL)
        }

        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destination1URL = tempDir.appendingPathComponent("\(#function)file1.txt")
        let destination2URL = tempDir.appendingPathComponent("\(#function)file2.txt")

        // Create and setup the downloader with multiple files
        let downloader = Downloader()
        
        let childDownloader1 = Downloader.ChildDownloader(
            url: file1URL,
            destinationURL: destination1URL,
            configuration: mockSessionConfiguration()
        )
        
        let childDownloader2 = Downloader.ChildDownloader(
            url: file2URL,
            destinationURL: destination2URL,
            configuration: mockSessionConfiguration()
        )
        
        downloader.add(childDownloader1)
        downloader.add(childDownloader2)
        
        #expect(downloader.downloaders.count == 2)
        #expect(downloader.progress.totalUnitCount == 2)
        
        // Start the downloads and wait for completion
        try await downloader.downloadAndAwait()
        
        // Verify all downloads completed successfully
        #expect(!downloader.isDownloading)
        #expect(downloader.isDownloaded)
        
        // Check first file
        #expect(FileManager.default.fileExists(atPath: destination1URL.path))
        if let data1 = try? Data(contentsOf: destination1URL) {
            #expect(data1 == file1Data)
        } else {
            Issue.record("First downloaded file could not be read")
        }
        
        // Check second file
        #expect(FileManager.default.fileExists(atPath: destination2URL.path))
        if let data2 = try? Data(contentsOf: destination2URL) {
            #expect(data2 == file2Data)
        } else {
            Issue.record("Second downloaded file could not be read")
        }
    }
    
    @Test(.disabled(if: canImportFoundationNetworking))
    func testProgressObservation() async throws {
        // Prepare the mock data
        let testData = Data(repeating: 0, count: 1000000) // 1MB of data
        let sourceURL = URL(string: "https://\(#function)")!

        // Setup the mock response
        MockURLProtocol.setResponse(for: sourceURL, with: testData)
        defer {
            MockURLProtocol.removeResponse(for: sourceURL)
        }

        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appendingPathComponent("\(#function).dat")

        // Create and setup the downloader
        let downloader = Downloader()
        let childDownloader = Downloader.ChildDownloader(
            url: sourceURL,
            destinationURL: destinationURL,
            configuration: mockSessionConfiguration()
        )
        
        downloader.add(childDownloader)
        
        // Track progress updates with a thread-safe container
        let progressUpdates = Locked<[Double]>([])
        
        await confirmation("Progress reaches 100%") { done in
            downloader.setObserver { progress in
                progressUpdates.withLock {
                    $0.append(progress.fractionCompleted)
                }
                if progress.fractionCompleted == 1.0 {
                    done()
                }
            }
            
            // Start the download
            try? await downloader.downloadAndAwait()
        }
        
        // Extract the final progress updates
        let finalProgressUpdates = progressUpdates.withLock { $0 }
        
        // Verify progress was tracked correctly
        #expect(finalProgressUpdates.count > 1)
        #expect(finalProgressUpdates.first == 0.0)
        #expect(finalProgressUpdates.last == 1.0)
        
        // Verify the download completed
        #expect(downloader.isDownloaded)
        #expect(FileManager.default.fileExists(atPath: destinationURL.path))
    }
    
    @Test(.disabled(if: canImportFoundationNetworking))
    func testAlreadyDownloadedFile() async throws {
        // Prepare the mock data
        let testData = "Test file content".data(using: .utf8)!
        let sourceURL = URL(string: "https://\(#function)")!

        // Setup the mock response
        MockURLProtocol.setResponse(for: sourceURL, with: testData)
        defer {
            MockURLProtocol.removeResponse(for: sourceURL)
        }

        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appendingPathComponent("\(#function).txt")
        
        // Create the file before downloading
        try testData.write(to: destinationURL)
        
        // Verify the file exists
        #expect(FileManager.default.fileExists(atPath: destinationURL.path))
        
        // Create and setup the downloader
        let downloader = Downloader()
        let childDownloader = Downloader.ChildDownloader(
            url: sourceURL,
            destinationURL: destinationURL,
            configuration: mockSessionConfiguration()
        )
        
        downloader.add(childDownloader)
        
        // The file should already be marked as downloaded
        #expect(childDownloader.isDownloaded)
        #expect(downloader.isDownloaded)
        
        // Start the download anyway
        try await downloader.downloadAndAwait()
        
        // Verify the download is still marked as complete
        #expect(!downloader.isDownloading)
        #expect(downloader.isDownloaded)
    }
}
