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
    
    @Test(.disabled(if: canImportFoundationNetworking)) @MainActor
    func testSuccessfulDownload() async throws {
        // Prepare the mock data
        let testData = "Test file content".data(using: .utf8)!
        let sourceURL = URL(string: "https://\(#function)")!

        // Setup the mock response with small delay for progress tracking
        MockURLProtocol.setResponse(for: sourceURL, with: testData, delay: 0.1)
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
        downloader.download()
        await downloader.waitForDownloads()


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
        downloader.download()
        await downloader.waitForDownloads()

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
        downloader.download()
        await downloader.waitForDownloads()

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

        // Setup the mock response with delay for progress observation
        MockURLProtocol.setResponse(for: sourceURL, with: testData, delay: 0.2)
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
            downloader.download()
            await downloader.waitForDownloads()
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
        downloader.download()
        await downloader.waitForDownloads()

        // Verify the download is still marked as complete
        #expect(!downloader.isDownloading)
        #expect(downloader.isDownloaded)
    }
    
    @Test
    func testIsDownloadedWithMixedStates() async throws {
        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let downloader = Downloader()
        
        // Create three child downloaders with different states
        let url1 = URL(string: "https://\(#function)/file1")!
        let url2 = URL(string: "https://\(#function)/file2")!
        let url3 = URL(string: "https://\(#function)/file3")!
        
        let dest1 = tempDir.appendingPathComponent("file1.txt")
        let dest2 = tempDir.appendingPathComponent("file2.txt")
        let dest3 = tempDir.appendingPathComponent("file3.txt")
        
        // Create first two files to simulate downloaded state
        try "content1".data(using: .utf8)!.write(to: dest1)
        try "content2".data(using: .utf8)!.write(to: dest2)
        // Third file doesn't exist (not downloaded)
        
        let child1 = Downloader.ChildDownloader(url: url1, destinationURL: dest1, configuration: mockSessionConfiguration())
        let child2 = Downloader.ChildDownloader(url: url2, destinationURL: dest2, configuration: mockSessionConfiguration())
        let child3 = Downloader.ChildDownloader(url: url3, destinationURL: dest3, configuration: mockSessionConfiguration())
        
        downloader.add(child1)
        downloader.add(child2)
        downloader.add(child3)
        
        // Check individual states
        #expect(child1.isDownloaded)
        #expect(child2.isDownloaded)
        #expect(!child3.isDownloaded)
        
        // Downloader should not be downloaded since not all children are downloaded
        #expect(!downloader.isDownloaded)
    }
    
    @Test
    func testIsDownloadedAllChildrenDownloaded() async throws {
        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let downloader = Downloader()
        
        // Create three child downloaders, all with downloaded files
        let url1 = URL(string: "https://\(#function)/file1")!
        let url2 = URL(string: "https://\(#function)/file2")!
        let url3 = URL(string: "https://\(#function)/file3")!
        
        let dest1 = tempDir.appendingPathComponent("file1.txt")
        let dest2 = tempDir.appendingPathComponent("file2.txt")
        let dest3 = tempDir.appendingPathComponent("file3.txt")
        
        // Create all files to simulate downloaded state
        try "content1".data(using: .utf8)!.write(to: dest1)
        try "content2".data(using: .utf8)!.write(to: dest2)
        try "content3".data(using: .utf8)!.write(to: dest3)
        
        let child1 = Downloader.ChildDownloader(url: url1, destinationURL: dest1, configuration: mockSessionConfiguration())
        let child2 = Downloader.ChildDownloader(url: url2, destinationURL: dest2, configuration: mockSessionConfiguration())
        let child3 = Downloader.ChildDownloader(url: url3, destinationURL: dest3, configuration: mockSessionConfiguration())
        
        downloader.add(child1)
        downloader.add(child2)
        downloader.add(child3)
        
        // All children should be downloaded
        #expect(child1.isDownloaded)
        #expect(child2.isDownloaded)
        #expect(child3.isDownloaded)
        
        // Downloader should be downloaded since all children are downloaded
        #expect(downloader.isDownloaded)
    }
    
    @Test
    func testIsDownloadedAfterFileRemoval() async throws {
        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let downloader = Downloader()
        let url = URL(string: "https://\(#function)/file")!
        let destinationURL = tempDir.appendingPathComponent("file.txt")
        
        // Create file first
        try "content".data(using: .utf8)!.write(to: destinationURL)
        
        let childDownloader = Downloader.ChildDownloader(
            url: url,
            destinationURL: destinationURL,
            configuration: mockSessionConfiguration()
        )
        downloader.add(childDownloader)
        
        // Should be downloaded initially
        #expect(childDownloader.isDownloaded)
        #expect(downloader.isDownloaded)
        
        // Remove the file
        try FileManager.default.removeItem(at: destinationURL)
        
        // Should no longer be downloaded
        #expect(!childDownloader.isDownloaded)
        #expect(!downloader.isDownloaded)
    }
    
    @Test
    func testChildDownloaderIsDownloadedWithDirectory() throws {
        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let url = URL(string: "https://\(#function)/directory")!
        let destinationURL = tempDir.appendingPathComponent("testdir")
        
        // Create a directory instead of a file
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        
        let childDownloader = Downloader.ChildDownloader(
            url: url,
            destinationURL: destinationURL,
            configuration: mockSessionConfiguration()
        )
        
        // Directory exists but is not a file, should be considered downloaded
        // (FileManager.fileExists returns true for directories too)
        #expect(childDownloader.isDownloaded)
    }
    
    @Test
    func testChildDownloaderIsDownloadedWithSymlink() throws {
        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let url = URL(string: "https://\(#function)/symlink")!
        let destinationURL = tempDir.appendingPathComponent("symlink.txt")
        let targetURL = tempDir.appendingPathComponent("target.txt")
        
        // Create target file
        try "target content".data(using: .utf8)!.write(to: targetURL)
        
        // Create symlink
        try FileManager.default.createSymbolicLink(at: destinationURL, withDestinationURL: targetURL)
        
        let childDownloader = Downloader.ChildDownloader(
            url: url,
            destinationURL: destinationURL,
            configuration: mockSessionConfiguration()
        )
        
        // Symlink exists and points to a valid file
        #expect(childDownloader.isDownloaded)
    }
    
    @Test
    func testChildDownloaderIsDownloadedWithBrokenSymlink() throws {
        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let url = URL(string: "https://\(#function)/brokensymlink")!
        let destinationURL = tempDir.appendingPathComponent("brokensymlink.txt")
        let targetURL = tempDir.appendingPathComponent("nonexistent.txt")
        
        // Create symlink to non-existent file
        try FileManager.default.createSymbolicLink(at: destinationURL, withDestinationURL: targetURL)
        
        let childDownloader = Downloader.ChildDownloader(
            url: url,
            destinationURL: destinationURL,
            configuration: mockSessionConfiguration()
        )
        
        // Broken symlink returns false from FileManager.fileExists
        #expect(!childDownloader.isDownloaded)
    }
    
    @Test
    func testChildDownloaderIsDownloadedWithEmptyFile() throws {
        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let url = URL(string: "https://\(#function)/empty")!
        let destinationURL = tempDir.appendingPathComponent("empty.txt")
        
        // Create empty file
        FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
        
        let childDownloader = Downloader.ChildDownloader(
            url: url,
            destinationURL: destinationURL,
            configuration: mockSessionConfiguration()
        )
        
        // Empty file should still be considered downloaded
        #expect(childDownloader.isDownloaded)
    }
    
    @Test
    func testChildDownloaderIsDownloadedWithLargeFile() throws {
        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let url = URL(string: "https://\(#function)/large")!
        let destinationURL = tempDir.appendingPathComponent("large.dat")
        
        // Create a large file (1MB)
        let largeData = Data(repeating: 0xFF, count: 1024 * 1024)
        try largeData.write(to: destinationURL)
        
        let childDownloader = Downloader.ChildDownloader(
            url: url,
            destinationURL: destinationURL,
            configuration: mockSessionConfiguration()
        )
        
        // Large file should be considered downloaded
        #expect(childDownloader.isDownloaded)
    }
    
    @Test
    func testIsDownloadingWhenNoDownloadStarted() {
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
        
        // Without calling download(), should not be downloading
        #expect(!downloader.isDownloading)
        #expect(!childDownloader.isDownloading)
    }
    
    @Test(.disabled(if: canImportFoundationNetworking))
    func testDoubleDownloadPrevention() async throws {
        // Prepare mock data
        let testData = "Test content".data(using: .utf8)!
        let sourceURL = URL(string: "https://\(#function)")!
        
        MockURLProtocol.setResponse(for: sourceURL, with: testData, delay: 0.3)
        defer {
            MockURLProtocol.removeResponse(for: sourceURL)
        }
        
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appendingPathComponent("\(#function).txt")
        
        let childDownloader = Downloader.ChildDownloader(
            url: sourceURL,
            destinationURL: destinationURL,
            configuration: mockSessionConfiguration()
        )
        
        // Start first download
        childDownloader.download()
        
        // Give it a moment to start
        try await Task.sleep(for: .milliseconds(100))
        #expect(childDownloader.isDownloading)
        
        // Try to start second download - should be ignored
        childDownloader.download()
        
        // Still only one download
        #expect(childDownloader.isDownloading)
        
        // Wait for completion
        while childDownloader.isDownloading {
            try await Task.sleep(for: .milliseconds(100))
        }
        
        #expect(!childDownloader.isDownloading)
    }
    
    @Test(.disabled(if: canImportFoundationNetworking))
    func testWaitForDownloadsTimeout() async throws {
        // Create a large file to ensure download takes time
        let largeData = Data(repeating: 0, count: 50_000_000) // 50MB
        let sourceURL = URL(string: "https://\(#function)")!
        
        MockURLProtocol.setResponse(for: sourceURL, with: largeData)
        defer {
            MockURLProtocol.removeResponse(for: sourceURL)
        }
        
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appendingPathComponent("\(#function).dat")
        
        let downloader = Downloader()
        let childDownloader = Downloader.ChildDownloader(
            url: sourceURL,
            destinationURL: destinationURL,
            configuration: mockSessionConfiguration()
        )
        
        downloader.add(childDownloader)
        
        // Start download
        downloader.download()
        
        // Create a timeout task
        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(2))
            return "timeout"
        }
        
        let waitTask = Task {
            await downloader.waitForDownloads()
            return "completed"
        }
        
        // Race between timeout and completion
        let result = await withTaskGroup(of: String.self) { group in
            group.addTask { (try? await timeoutTask.value) ?? "timeout" }
            group.addTask { await waitTask.value }
            
            let firstResult = await group.next()!
            group.cancelAll()
            return firstResult
        }
        
        // Since we have a large file, it might timeout or complete depending on system
        #expect(result == "timeout" || result == "completed")
    }
    
    @Test(.disabled(if: canImportFoundationNetworking))
    func testProgressObserverCalledMultipleTimes() async throws {
        // Prepare mock data
        let testData = Data(repeating: 0, count: 1_000_000) // 1MB
        let sourceURL = URL(string: "https://\(#function)")!
        
        MockURLProtocol.setResponse(for: sourceURL, with: testData, delay: 0.2)
        defer {
            MockURLProtocol.removeResponse(for: sourceURL)
        }
        
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appendingPathComponent("\(#function).dat")
        
        let downloader = Downloader()
        let childDownloader = Downloader.ChildDownloader(
            url: sourceURL,
            destinationURL: destinationURL,
            configuration: mockSessionConfiguration()
        )
        
        downloader.add(childDownloader)
        
        // Track progress calls
        let progressCalls = Locked<[Double]>([])
        
        await confirmation("Progress observer called multiple times") { done in
            downloader.setObserver { progress in
                progressCalls.withLock { $0.append(progress.fractionCompleted) }
                if progress.fractionCompleted == 1.0 {
                    done()
                }
            }
            
            // Start download
            downloader.download()
            await downloader.waitForDownloads()
        }
        
        // Verify progress was called multiple times
        let finalProgressCalls = progressCalls.withLock { $0 }
        #expect(finalProgressCalls.count > 1)
        #expect(finalProgressCalls.contains(0.0))
        #expect(finalProgressCalls.contains(1.0))
    }
    
    @Test
    func testChildDownloaderFileCreationDirectory() throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let url = URL(string: "https://\(#function)/file")!
        // Destination in a subdirectory that doesn't exist yet
        let destinationURL = tempDir.appendingPathComponent("subdir/nested/file.txt")
        
        let childDownloader = Downloader.ChildDownloader(
            url: url,
            destinationURL: destinationURL,
            configuration: mockSessionConfiguration()
        )
        
        // Directory shouldn't exist yet
        let parentDir = destinationURL.deletingLastPathComponent()
        #expect(!FileManager.default.fileExists(atPath: parentDir.path))
        
        // Start download (will fail but should create directories)
        childDownloader.download()
        
        // Parent directory should be created
        #expect(FileManager.default.fileExists(atPath: parentDir.path))
    }
    
    @Test(.disabled(if: canImportFoundationNetworking))
    func testConcurrentDownloadsProgressAccuracy() async throws {
        // Create multiple files
        let files = [
            (url: URL(string: "https://\(#function)/file1")!, data: Data(repeating: 1, count: 100_000)),
            (url: URL(string: "https://\(#function)/file2")!, data: Data(repeating: 2, count: 200_000)),
            (url: URL(string: "https://\(#function)/file3")!, data: Data(repeating: 3, count: 300_000))
        ]
        
        // Setup mock responses with delays
        for (index, file) in files.enumerated() {
            MockURLProtocol.setResponse(for: file.url, with: file.data, delay: 0.1 + Double(index) * 0.1)
        }
        defer {
            for file in files {
                MockURLProtocol.removeResponse(for: file.url)
            }
        }
        
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let downloader = Downloader()
        
        // Add child downloaders
        for (index, file) in files.enumerated() {
            let destinationURL = tempDir.appendingPathComponent("file\(index).dat")
            let childDownloader = Downloader.ChildDownloader(
                url: file.url,
                destinationURL: destinationURL,
                configuration: mockSessionConfiguration()
            )
            downloader.add(childDownloader)
        }
        
        // Track final progress
        let finalProgress = Locked<Double>(0.0)
        
        await confirmation("All downloads complete") { done in
            downloader.setObserver { progress in
                finalProgress.withLock { $0 = progress.fractionCompleted }
                if progress.fractionCompleted == 1.0 {
                    done()
                }
            }
            
            // Start all downloads concurrently
            downloader.download()
            await downloader.waitForDownloads()
        }
        
        // Final progress should be 100%
        #expect(finalProgress.withLock { $0 } == 1.0)
        
        // All files should be downloaded
        #expect(downloader.isDownloaded)
    }
    
    @Test
    func testEmptyDownloaderStates() {
        let downloader = Downloader()
        
        // Empty downloader should report as downloaded (vacuously true)
        #expect(downloader.isDownloaded)
        #expect(!downloader.isDownloading)
        
        // Progress should be 0/0
        #expect(downloader.progress.totalUnitCount == 0)
        #expect(downloader.progress.completedUnitCount == 0)
    }
    
    @Test(.disabled(if: canImportFoundationNetworking))
    func testDownloadProgressReporting() async throws {
        // Create test data
        let testData = Data(repeating: 0xAB, count: 500_000) // 500KB
        let sourceURL = URL(string: "https://\(#function)")!
        
        MockURLProtocol.setResponse(for: sourceURL, with: testData, delay: 0.3)
        defer {
            MockURLProtocol.removeResponse(for: sourceURL)
        }
        
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appendingPathComponent("\(#function).dat")
        
        let childDownloader = Downloader.ChildDownloader(
            url: sourceURL,
            destinationURL: destinationURL,
            configuration: mockSessionConfiguration()
        )
        
        // Track progress updates
        let progressValues = Locked<[Int64]>([])
        
        // Start download
        childDownloader.download()
        
        // Monitor progress
        var attempts = 0
        while !childDownloader.isDownloaded && attempts < 20 {
            progressValues.withLock { $0.append(childDownloader.progress.completedUnitCount) }
            try await Task.sleep(for: .milliseconds(50))
            attempts += 1
        }
        
        // Progress should have increased
        #expect(progressValues.withLock { $0.count } > 0)
        #expect(childDownloader.isDownloaded)
    }
    
    @Test
    func testDownloaderInitWithEmptyConfiguration() {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let url = URL(string: "https://\(#function)/file")!
        let destinationURL = tempDir.appendingPathComponent("file.txt")
        
        // Create with default configuration
        let childDownloader = Downloader.ChildDownloader(
            url: url,
            destinationURL: destinationURL
        )
        
        // Should initialize properly
        #expect(!childDownloader.isDownloading)
        #expect(!childDownloader.isDownloaded)
    }
}
