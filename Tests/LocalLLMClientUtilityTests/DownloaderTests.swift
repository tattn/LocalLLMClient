import Foundation
import Testing
#if canImport(FoundationNetworking)
import FoundationNetworking
let canImportFoundationNetworking = true
#else
let canImportFoundationNetworking = false
#endif
@testable import LocalLLMClientUtility

@MainActor
struct DownloaderTests {
    
    /// Helper function to create a temporary directory for test file downloads
    private nonisolated func createTemporaryDirectory() -> URL {
        let tempDirURL = FileManager.default.temporaryDirectory.appending(
            path: "DownloaderTests_\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try? FileManager.default.createDirectory(
            at: tempDirURL,
            withIntermediateDirectories: true
        )
        return tempDirURL
    }
    
    /// Cleanup temporary files after tests
    private nonisolated func cleanupTemporaryDirectory(_ url: URL) {
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

        let mock = MockResponse(data: Data())
        let destinationURL = tempDir.appending(path: "\(#function).txt")
        let childDownloader = Downloader.ChildDownloader(
            mock: mock,
            destinationURL: destinationURL
        )
        
        downloader.add(childDownloader)
        
        #expect(downloader.downloaders.count == 1)
        #expect(downloader.progress.totalUnitCount == 0) // Update after download() is called
    }
    
    @Test
    func testEmptyDownloadCompletes() async {
        let downloader = Downloader()
        
        // Download should immediately complete when no downloaders are added
        await downloader.download()
        
        #expect(downloader.progress.totalUnitCount == 1)
        #expect(downloader.progress.completedUnitCount == 1)
        #expect(!downloader.isDownloading)
        #expect(downloader.isDownloaded)
    }
    
    @Test(.disabled(if: canImportFoundationNetworking)) @MainActor
    func testSuccessfulDownload() async throws {
        // Setup the mock response with small delay for progress tracking
        let testData = "Test file content".data(using: .utf8)!
        let mock = MockResponse(
            data: testData,
            delay: 0.1
        )

        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        // Create and setup the downloader
        let destinationURL = tempDir.appending(path: "\(#function).txt")
        
        let downloader = Downloader()
        let childDownloader = Downloader.ChildDownloader(
            mock: mock,
            destinationURL: destinationURL
        )
        
        downloader.add(childDownloader)
        
        // Track progress updates
        var progressUpdates: [Double] = []
        downloader.setObserver { @MainActor progress in
            progressUpdates.append(progress.fractionCompleted)
        }
        
        // Start the download and wait for completion
        await downloader.download()
        try await downloader.waitForDownloads()


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
        let error = NSError(domain: "com.test.downloader", code: 42, userInfo: [NSLocalizedDescriptionKey: "Mock download error"])

        // Setup the mock response with error
        let mock = MockResponse(
            data: Data(),
            error: error
        )
        

        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appending(path: "\(#function).txt")
        
        // Create and setup the downloader
        let downloader = Downloader()
        let childDownloader = Downloader.ChildDownloader(
            mock: mock,
            destinationURL: destinationURL
        )
        
        downloader.add(childDownloader)
        
        // Start the download and wait for completion
        await downloader.download()
        await #expect {
            try await downloader.waitForDownloads()
        } throws: { thrownError in
            thrownError._domain == error.domain
        }

        // Verify the download completed with error
        #expect(!downloader.isDownloading)
        #expect(!FileManager.default.fileExists(atPath: destinationURL.path))
    }
    
    @Test(.disabled(if: canImportFoundationNetworking))
    func testMultipleDownloads() async throws {
        // Setup mock responses
        let file1Data = "File 1 content".data(using: .utf8)!
        let file2Data = "File 2 content".data(using: .utf8)!
        
        let mocks = [
            MockResponse(data: file1Data),
            MockResponse(data: file2Data)
        ]

        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destination1URL = tempDir.appending(path: "\(#function)file1.txt")
        let destination2URL = tempDir.appending(path: "\(#function)file2.txt")

        // Create and setup the downloader with multiple files
        let downloader = Downloader()
        
        let childDownloader1 = Downloader.ChildDownloader(
            mock: mocks[0],
            destinationURL: destination1URL
        )
        
        let childDownloader2 = Downloader.ChildDownloader(
            mock: mocks[1],
            destinationURL: destination2URL
        )
        
        downloader.add(childDownloader1)
        downloader.add(childDownloader2)
        
        #expect(downloader.downloaders.count == 2)
        #expect(downloader.progress.totalUnitCount == 0) // Update after download() is called
        
        // Start the downloads and wait for completion
        await downloader.download()
        try await downloader.waitForDownloads()

        // Verify all downloads completed successfully
        #expect(!downloader.isDownloading)
        #expect(downloader.isDownloaded)
        #expect(downloader.progress.totalUnitCount == 28)

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
        // Setup the mock response with delay for progress observation
        let mock = MockResponse(
            data: Data(repeating: 0, count: 1000000), // 1MB of data
            delay: 0.2
        )
        

        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appending(path: "\(#function).dat")
        
        // Create and setup the downloader
        let downloader = Downloader()
        let childDownloader = Downloader.ChildDownloader(
            mock: mock,
            destinationURL: destinationURL
        )
        
        downloader.add(childDownloader)
        
        // Track progress updates with a thread-safe container
        let progressUpdates = Locked<[Double]>([])
        
        try await confirmation("Progress reaches 100%") { done in
            downloader.setObserver { progress in
                progressUpdates.withLock {
                    $0.append(progress.fractionCompleted)
                }
                if progress.fractionCompleted == 1.0 {
                    done()
                }
            }
            
            // Start the download
            await downloader.download()
            try await downloader.waitForDownloads()
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
        // Setup the mock response
        let testData = "Test file content".data(using: .utf8)!
        let mock = MockResponse(
            data: testData
        )
        

        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appending(path: "\(#function).txt")
        
        // Create the file before downloading
        try testData.write(to: destinationURL)
        
        // Verify the file exists
        #expect(FileManager.default.fileExists(atPath: destinationURL.path))
        
        // Create and setup the downloader
        let downloader = Downloader()
        let childDownloader = Downloader.ChildDownloader(mock: mock, destinationURL: destinationURL)
        
        downloader.add(childDownloader)
        
        // The file should already be marked as downloaded
        #expect(childDownloader.isDownloaded)
        #expect(downloader.isDownloaded)
        
        // Start the download anyway
        await downloader.download()
        try await downloader.waitForDownloads()

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
        
        // Create three mock responses
        let mock1 = MockResponse(content: "content1")
        let mock2 = MockResponse(content: "content2")
        let mock3 = MockResponse(content: "content3")
        
        let dest1 = tempDir.appending(path: "file1.txt")
        let dest2 = tempDir.appending(path: "file2.txt")
        let dest3 = tempDir.appending(path: "file3.txt")
        
        // Create first two files to simulate downloaded state
        try "content1".data(using: .utf8)!.write(to: dest1)
        try "content2".data(using: .utf8)!.write(to: dest2)
        // Third file doesn't exist (not downloaded)
        
        let child1 = Downloader.ChildDownloader(mock: mock1, destinationURL: dest1)
        let child2 = Downloader.ChildDownloader(mock: mock2, destinationURL: dest2)
        let child3 = Downloader.ChildDownloader(mock: mock3, destinationURL: dest3)
        
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
        
        // Create three mock responses
        let mock1 = MockResponse(content: "content1")
        let mock2 = MockResponse(content: "content2")
        let mock3 = MockResponse(content: "content3")
        
        let dest1 = tempDir.appending(path: "file1.txt")
        let dest2 = tempDir.appending(path: "file2.txt")
        let dest3 = tempDir.appending(path: "file3.txt")
        
        // Create all files to simulate downloaded state
        try "content1".data(using: .utf8)!.write(to: dest1)
        try "content2".data(using: .utf8)!.write(to: dest2)
        try "content3".data(using: .utf8)!.write(to: dest3)
        
        let child1 = Downloader.ChildDownloader(mock: mock1, destinationURL: dest1)
        let child2 = Downloader.ChildDownloader(mock: mock2, destinationURL: dest2)
        let child3 = Downloader.ChildDownloader(mock: mock3, destinationURL: dest3)
        
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
        let mock = MockResponse(content: "content")
        let destinationURL = tempDir.appending(path: "file.txt")
        
        // Create file first
        try "content".data(using: .utf8)!.write(to: destinationURL)
        
        let childDownloader = Downloader.ChildDownloader(mock: mock, destinationURL: destinationURL)
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
        
        let mock = MockResponse(data: Data())
        let destinationURL = tempDir.appending(path: "testdir")
        
        // Create a directory instead of a file
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        
        let childDownloader = Downloader.ChildDownloader(mock: mock, destinationURL: destinationURL)
        
        // Directory exists but is not a file, should be considered downloaded
        // (FileManager.fileExists returns true for directories too)
        #expect(childDownloader.isDownloaded)
    }
    
    @Test
    func testChildDownloaderIsDownloadedWithSymlink() throws {
        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let mock = MockResponse(content: "target content")
        let destinationURL = tempDir.appending(path: "symlink.txt")
        let targetURL = tempDir.appending(path: "target.txt")
        
        // Create target file
        try "target content".data(using: .utf8)!.write(to: targetURL)
        
        // Create symlink
        try FileManager.default.createSymbolicLink(at: destinationURL, withDestinationURL: targetURL)
        
        let childDownloader = Downloader.ChildDownloader(mock: mock, destinationURL: destinationURL)
        
        // Symlink exists and points to a valid file
        #expect(childDownloader.isDownloaded)
    }
    
    @Test
    func testChildDownloaderIsDownloadedWithBrokenSymlink() throws {
        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let mock = MockResponse(data: Data())
        let destinationURL = tempDir.appending(path: "brokensymlink.txt")
        let targetURL = tempDir.appending(path: "nonexistent.txt")
        
        // Create symlink to non-existent file
        try FileManager.default.createSymbolicLink(at: destinationURL, withDestinationURL: targetURL)
        
        let childDownloader = Downloader.ChildDownloader(mock: mock, destinationURL: destinationURL)
        
        // Broken symlink returns false from FileManager.fileExists
        #expect(!childDownloader.isDownloaded)
    }
    
    @Test
    func testChildDownloaderIsDownloadedWithEmptyFile() throws {
        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let mock = MockResponse(data: Data())
        let destinationURL = tempDir.appending(path: "empty.txt")
        
        // Create empty file
        FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
        
        let childDownloader = Downloader.ChildDownloader(mock: mock, destinationURL: destinationURL)
        
        // Empty file should still be considered downloaded
        #expect(childDownloader.isDownloaded)
    }
    
    @Test
    func testChildDownloaderIsDownloadedWithLargeFile() throws {
        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let largeData = Data(repeating: 0xFF, count: 1024 * 1024)
        let mock = MockResponse(data: largeData)
        let destinationURL = tempDir.appending(path: "large.dat")
        
        // Create a large file (1MB)
        try largeData.write(to: destinationURL)
        
        let childDownloader = Downloader.ChildDownloader(mock: mock, destinationURL: destinationURL)
        
        // Large file should be considered downloaded
        #expect(childDownloader.isDownloaded)
    }
    
    @Test
    func testIsDownloadingWhenNoDownloadStarted() {
        let downloader = Downloader()
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let mock = MockResponse(data: Data())
        let destinationURL = tempDir.appending(path: "\(#function).txt")
        let childDownloader = Downloader.ChildDownloader(
            mock: mock,
            destinationURL: destinationURL
        )
        
        downloader.add(childDownloader)
        
        // Without calling download(), should not be downloading
        #expect(!downloader.isDownloading)
        #expect(!childDownloader.isDownloading)
    }
    
    @Test(.disabled(if: canImportFoundationNetworking))
    func testDoubleDownloadPrevention() async throws {
        // Prepare mock data
        let mock = MockResponse(
            content: "Test content",
            delay: 0.3
        )
        
        
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appending(path: "\(#function).txt")
        let childDownloader = Downloader.ChildDownloader(
            mock: mock,
            destinationURL: destinationURL
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
        let mock = MockResponse(
            data: Data(repeating: 0, count: 50_000_000) // 50MB
        )
        
        
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appending(path: "\(#function).dat")
        
        let downloader = Downloader()
        let childDownloader = Downloader.ChildDownloader(mock: mock, destinationURL: destinationURL)
        
        downloader.add(childDownloader)
        
        // Start download
        await downloader.download()
        
        // Create a timeout task
        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(2))
            return "timeout"
        }
        
        let waitTask = Task {
            try await downloader.waitForDownloads()
            return "completed"
        }
        
        // Race between timeout and completion
        let result = await withTaskGroup(of: String.self) { group in
            group.addTask { (try? await timeoutTask.value) ?? "timeout" }
            group.addTask { (try? await waitTask.value) ?? "error" }
            
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
        let mock = MockResponse(
            data: Data(repeating: 0, count: 1_000_000), // 1MB
            delay: 0.2
        )
        
        
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appending(path: "\(#function).dat")
        
        let downloader = Downloader()
        let childDownloader = Downloader.ChildDownloader(mock: mock, destinationURL: destinationURL)
        
        downloader.add(childDownloader)
        
        // Track progress calls
        let progressCalls = Locked<[Double]>([])
        
        try await confirmation("Progress observer called multiple times") { done in
            downloader.setObserver { progress in
                progressCalls.withLock { $0.append(progress.fractionCompleted) }
                if progress.fractionCompleted == 1.0 {
                    done()
                }
            }
            
            // Start download
            await downloader.download()
            try await downloader.waitForDownloads()
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
        
        let mock = MockResponse(data: Data())
        // Destination in a subdirectory that doesn't exist yet
        let destinationURL = tempDir.appending(path: "subdir/nested/file.txt")
        let childDownloader = Downloader.ChildDownloader(
            mock: mock,
            destinationURL: destinationURL
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
        let filesData = [
            Data(repeating: 1, count: 100_000),
            Data(repeating: 2, count: 200_000),
            Data(repeating: 3, count: 300_000)
        ]
        
        // Setup mock responses with delays
        let mocks = [
            MockResponse(data: filesData[0], delay: 0.1),
            MockResponse(data: filesData[1], delay: 0.2),
            MockResponse(data: filesData[2], delay: 0.3)
        ]
        
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let downloader = Downloader()
        
        // Add child downloaders
        for (index, mock) in mocks.enumerated() {
            let destinationURL = tempDir.appending(path: "file\(index).dat")
            let childDownloader = Downloader.ChildDownloader(
                mock: mock,
                destinationURL: destinationURL
            )
            downloader.add(childDownloader)
        }
        
        // Track final progress
        let finalProgress = Locked<Double>(0.0)
        
        try await confirmation("All downloads complete") { done in
            downloader.setObserver { progress in
                finalProgress.withLock { $0 = progress.fractionCompleted }
                if progress.fractionCompleted == 1.0 {
                    done()
                }
            }
            
            // Start all downloads concurrently
            await downloader.download()
            try await downloader.waitForDownloads()
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
        let mock = MockResponse(
            data: Data(repeating: 0xAB, count: 500_000), // 500KB
            delay: 0.1
        )
        
        
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appending(path: "\(#function).dat")
        let childDownloader = Downloader.ChildDownloader(
            mock: mock,
            destinationURL: destinationURL
        )
        
        // Track progress updates
        let progressValues = Locked<[Int64]>([])
        
        // Start download
        childDownloader.download()
        
        // Monitor progress
        var attempts = 0
        while !childDownloader.isDownloaded && attempts < 200 {
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
        
        let mock = MockResponse(data: Data())
        let destinationURL = tempDir.appending(path: "file.txt")
        
        // Create with mock configuration
        let childDownloader = Downloader.ChildDownloader(
            mock: mock,
            destinationURL: destinationURL
        )
        
        // Should initialize properly
        #expect(!childDownloader.isDownloading)
        #expect(!childDownloader.isDownloaded)
    }
    
    @Test(.disabled(if: canImportFoundationNetworking)) @MainActor
    func testDownloadCancellation() async throws {
        // Setup mock to simulate a slow download
        let mock = MockResponse(
            data: Data(repeating: 0, count: 1024 * 1024), // 1MB
            delay: 10.0 // 10 seconds delay
        )
        
        
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appending(path: "\(#function).bin")
        
        // Create downloader with slow download
        let downloader = Downloader()
        let childDownloader = Downloader.ChildDownloader(mock: mock, destinationURL: destinationURL)
        downloader.add(childDownloader)
        
        // Start download in a task
        await downloader.download()
        
        let waitTask = Task {
            try await downloader.waitForDownloads()
        }
        
        // Give it a moment to start
        try await Task.sleep(for: .milliseconds(100))
        
        // Cancel the download and the wait task
        downloader.cancelAllDownloads()
        
        // Verify the task finished
        await #expect {
            try await waitTask.value
        } throws: { thrownError in
            if case let error as URLError = thrownError {
                return error.code == .cancelled
            }
            return false
        }
        #expect(!childDownloader.isDownloading)

        // Verify file was cleaned up
        #expect(!FileManager.default.fileExists(atPath: destinationURL.path))
    }

    @Test(.disabled(if: canImportFoundationNetworking)) @MainActor
    func testDownloadCancellationUsingTask() async throws {
        // Setup mock to simulate a slow download
        let mock = MockResponse(
            data: Data(repeating: 0, count: 1024 * 1024), // 1MB
            delay: 10.0 // 10 seconds delay
        )
        

        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let destinationURL = tempDir.appending(path: "\(#function).bin")

        // Create downloader with slow download
        let downloader = Downloader()
        let childDownloader = Downloader.ChildDownloader(mock: mock, destinationURL: destinationURL)
        downloader.add(childDownloader)

        // Start download in a task
        await downloader.download()

        let waitTask = Task {
            try await downloader.waitForDownloads()
        }

        // Give it a moment to start
        try await Task.sleep(for: .milliseconds(100))

        // Cancel the download and the wait task
        waitTask.cancel()

        // Verify the task finished
        await #expect(throws: CancellationError.self) {
            try await waitTask.value
        }
        #expect(!childDownloader.isDownloading)

        // Verify file was cleaned up
        #expect(!FileManager.default.fileExists(atPath: destinationURL.path))
    }

    @Test(.disabled(if: canImportFoundationNetworking)) @MainActor
    func testChildDownloaderCancellation() async throws {
        // Setup mock to simulate a slow download
        let mock = MockResponse(
            data: Data(repeating: 0, count: 1024 * 1024), // 1MB
            delay: 5.0 // 5 seconds delay
        )
        
        
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appending(path: "\(#function).bin")
        
        // Create child downloader
        let childDownloader = Downloader.ChildDownloader(mock: mock, destinationURL: destinationURL)
        
        // Start download
        childDownloader.download()
        #expect(childDownloader.isDownloading)
        
        // Give it a moment to start
        try await Task.sleep(for: .milliseconds(100))
        
        // Cancel the download
        childDownloader.cancel()
        
        // Verify cancellation
        #expect(!childDownloader.isDownloading)
        #expect(!FileManager.default.fileExists(atPath: destinationURL.path))
    }
    
    @Test(.disabled(if: canImportFoundationNetworking)) @MainActor
    func testFetchFileSize() async throws {
        // Setup the mock response with Content-Length header
        let mock = MockResponse(
            data: Data(repeating: 0xAB, count: 12345)
        )
        
        
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appending(path: "\(#function).dat")
        let childDownloader = Downloader.ChildDownloader(
            mock: mock,
            destinationURL: destinationURL
        )
        
        // Fetch file size
        let size = await childDownloader.fetchFileSize()
        
        // Should return the data size
        #expect(size == 12345)
    }
    
    @Test @MainActor
    func testFetchFileSizeForDownloadedFile() async throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let mock = MockResponse(content: "content")
        let destinationURL = tempDir.appending(path: "\(#function).txt")
        
        // Create file to simulate already downloaded
        try "content".data(using: .utf8)!.write(to: destinationURL)
        
        let childDownloader = Downloader.ChildDownloader(mock: mock, destinationURL: destinationURL)
        
        // Should return 0 for already downloaded file
        let size = await childDownloader.fetchFileSize()
        #expect(size == 0)
    }
    
    @Test(.disabled(if: canImportFoundationNetworking)) @MainActor
    func testByteBasedProgress() async throws {
        // Setup mock responses with different sizes
        let mocks = [
            MockResponse(data: Data(repeating: 1, count: 1000)), // 1KB
            MockResponse(data: Data(repeating: 2, count: 3000)), // 3KB
            MockResponse(data: Data(repeating: 3, count: 6000))  // 6KB
        ]
        
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let downloader = Downloader()
        
        // Add child downloaders
        let dest1 = tempDir.appending(path: "file1.dat")
        let dest2 = tempDir.appending(path: "file2.dat")
        let dest3 = tempDir.appending(path: "file3.dat")
        
        downloader.add(Downloader.ChildDownloader(mock: mocks[0], destinationURL: dest1))
        downloader.add(Downloader.ChildDownloader(mock: mocks[1], destinationURL: dest2))
        downloader.add(Downloader.ChildDownloader(mock: mocks[2], destinationURL: dest3))
        
        // Start download
        await downloader.download()
        
        // Total unit count should be sum of all file sizes (1000 + 3000 + 6000 = 10000 bytes)
        #expect(downloader.progress.totalUnitCount == 10000)
        
        try await downloader.waitForDownloads()
        
        // Verify all downloads completed
        #expect(downloader.isDownloaded)
        #expect(FileManager.default.fileExists(atPath: dest1.path))
        #expect(FileManager.default.fileExists(atPath: dest2.path))
        #expect(FileManager.default.fileExists(atPath: dest3.path))
    }
    
    @Test(.disabled(if: canImportFoundationNetworking)) @MainActor
    func testProgressWithMixedDownloadedFiles() async throws {
        // Setup mock responses
        let file1Data = Data(repeating: 1, count: 2000) // 2KB
        let file2Data = Data(repeating: 2, count: 3000) // 3KB
        
        let mocks = [
            MockResponse(data: file1Data),
            MockResponse(data: file2Data)
        ]
        
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let dest1 = tempDir.appending(path: "file1.dat")
        let dest2 = tempDir.appending(path: "file2.dat")
        
        // Pre-download file1
        try file1Data.write(to: dest1)
        
        let downloader = Downloader()
        
        downloader.add(Downloader.ChildDownloader(mock: mocks[0], destinationURL: dest1))
        downloader.add(Downloader.ChildDownloader(mock: mocks[1], destinationURL: dest2))
        
        // Start download
        await downloader.download()
        
        // Only file2 should contribute to progress (file1 is already downloaded)
        // The totalUnitCount should reflect only file2's size (3000 bytes)
        #expect(downloader.progress.totalUnitCount == 3000)
        
        try await downloader.waitForDownloads()
        
        #expect(downloader.isDownloaded)
    }
    
    @Test(.disabled(if: canImportFoundationNetworking)) @MainActor
    func testProgressWithFailedSizeFetch() async throws {
        // Mock will return data for GET but fail for HEAD request
        let mock = MockResponse(
            data: Data(repeating: 0xFF, count: 5000),
            failHead: true
        )
        
        
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        let destinationURL = tempDir.appending(path: "file.dat")
        
        let downloader = Downloader()
        let childDownloader = Downloader.ChildDownloader(mock: mock, destinationURL: destinationURL)
        
        downloader.add(childDownloader)
        
        // Start download
        await downloader.download()
        
        // Should use default weight when HEAD fails (1_000_000)
        #expect(downloader.progress.totalUnitCount == 1_000_000)

        try await downloader.waitForDownloads()
        
        // Download should still succeed even though HEAD failed
        #expect(downloader.isDownloaded)
        #expect(FileManager.default.fileExists(atPath: destinationURL.path))
    }
}

final class MockResponse {
    let url: URL

    init(data: Data, statusCode: Int = 200, error: Error? = nil, delay: TimeInterval? = nil, failHead: Bool = false) {
        self.url = URL(string: "https://test.example.com/\(UUID().uuidString)")!
        MockURLProtocol.setResponse(for: url, with: data, statusCode: statusCode, error: error, delay: delay, failHead: failHead)
    }

    convenience init(content: String, statusCode: Int = 200, error: Error? = nil, delay: TimeInterval? = nil, failHead: Bool = false) {
        self.init(data: Data(content.utf8), statusCode: statusCode, error: error, delay: delay, failHead: failHead)
    }

    deinit {
        MockURLProtocol.removeResponse(for: url)
    }
}


// MARK: - Test Helper Extensions

private extension Downloader.ChildDownloader {
    /// Creates a mock session configuration with MockURLProtocol
    nonisolated static func mockSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return configuration
    }

    /// Convenience initializer for creating a ChildDownloader with mock response and explicit destination URL
    convenience init(mock: MockResponse, destinationURL: URL) {
        self.init(
            url: mock.url,
            destinationURL: destinationURL,
            configuration: Self.mockSessionConfiguration(),
            headSessionConfiguration: Self.mockSessionConfiguration()
        )
    }
}
