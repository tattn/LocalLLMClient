import Foundation
import Testing
#if canImport(Hub)
import Hub
#endif
@testable import LocalLLMClientUtility

struct FileDownloaderTests {
    @Test
    func testFileDownloaderInitialization() async throws {
        let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("FileDownloaderTests")

        // Initialize a FileDownloader with Hugging Face source
        let globs: Globs = ["*.safetensors", "*.json"]
        let source = FileDownloader.Source.huggingFace(id: "test-org/test-repo", globs: globs)
        let downloader = FileDownloader(source: source, destination: testDirectory)
        
        // Verify the initialization
        #expect(downloader.source == source)
        #expect(downloader.destination.pathComponents[(downloader.destination.pathComponents.count - 5)...] == ["FileDownloaderTests", "huggingface", "models", "test-org", "test-repo"])
    }

#if canImport(Hub)
    @Test
    func checkCompatibilityWithHuggingFaceAPI() async throws {
        let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("FileDownloaderTests")

        // Initialize a FileDownloader with Hugging Face source
        let globs: Globs = ["*.safetensors", "*.json"]
        let source = FileDownloader.Source.huggingFace(id: "test-org/test-repo", globs: globs)
        let downloader = FileDownloader(source: source, destination: testDirectory)

        let hub = HubApi(
            downloadBase: testDirectory.appending(component: "huggingface"),
            useOfflineMode: false
        )
        let hubDestination = hub.localRepoLocation(Hub.Repo(id: "test-org/test-repo"))
        #expect(downloader.destination == hubDestination)
    }
#endif

    @Test
    func testIsDownloadedWhenDestinationDoesNotExist() {
        let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("FileDownloaderTests_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testDirectory) }
        
        let globs: Globs = ["*.safetensors"]
        let source = FileDownloader.Source.huggingFace(id: "test-org/test-repo", globs: globs)
        let downloader = FileDownloader(source: source, destination: testDirectory)
        
        // Destination does not exist, so isDownloaded should be false
        #expect(!downloader.isDownloaded)
    }
    
    @Test
    func testIsDownloadedWhenMetadataDoesNotExist() {
        let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("FileDownloaderTests_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testDirectory) }
        
        let globs: Globs = ["*.safetensors"]
        let source = FileDownloader.Source.huggingFace(id: "test-org/test-repo", globs: globs)
        let downloader = FileDownloader(source: source, destination: testDirectory)
        
        // Create destination directory but no metadata
        try? FileManager.default.createDirectory(at: downloader.destination, withIntermediateDirectories: true)
        
        // Even though directory exists, without metadata it should be false
        #expect(!downloader.isDownloaded)
    }
    
    @Test
    func testIsDownloadedWhenFilesMatchMetadata() throws {
        let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("FileDownloaderTests_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testDirectory) }
        
        let globs: Globs = ["*.safetensors"]
        let source = FileDownloader.Source.huggingFace(id: "test-org/test-repo", globs: globs)
        let downloader = FileDownloader(source: source, destination: testDirectory)
        
        // Create destination with files and metadata
        let destination = downloader.destination
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        
        // Create test files
        let file1Data = "test content 1".data(using: .utf8)!
        let file1URL = destination.appendingPathComponent("model.safetensors")
        try file1Data.write(to: file1URL)
        
        let file2Data = "test content 2 longer".data(using: .utf8)!
        let file2URL = destination.appendingPathComponent("config.json")
        try file2Data.write(to: file2URL)
        
        // Create matching metadata
        let metadata = FilesMetadata(files: [
            FilesMetadata.FileMetadata(name: "model.safetensors", size: file1Data.count),
            FilesMetadata.FileMetadata(name: "config.json", size: file2Data.count)
        ])
        try metadata.save(to: destination)
        
        // All files match metadata, should be downloaded
        #expect(downloader.isDownloaded)
    }
    
    @Test
    func testIsDownloadedWhenFileIsMissing() throws {
        let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("FileDownloaderTests_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testDirectory) }
        
        let globs: Globs = ["*.safetensors"]
        let source = FileDownloader.Source.huggingFace(id: "test-org/test-repo", globs: globs)
        let downloader = FileDownloader(source: source, destination: testDirectory)
        
        // Create destination with only one file but metadata expects two
        let destination = downloader.destination
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        
        // Create only one file
        let file1Data = "test content 1".data(using: .utf8)!
        let file1URL = destination.appendingPathComponent("model.safetensors")
        try file1Data.write(to: file1URL)
        
        // Create metadata expecting two files
        let metadata = FilesMetadata(files: [
            FilesMetadata.FileMetadata(name: "model.safetensors", size: file1Data.count),
            FilesMetadata.FileMetadata(name: "config.json", size: 10) // This file doesn't exist
        ])
        try metadata.save(to: destination)
        
        // One file is missing, should not be downloaded
        #expect(!downloader.isDownloaded)
    }
    
    @Test
    func testIsDownloadedWhenFileSizeMismatch() throws {
        let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("FileDownloaderTests_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testDirectory) }
        
        let globs: Globs = ["*.safetensors"]
        let source = FileDownloader.Source.huggingFace(id: "test-org/test-repo", globs: globs)
        let downloader = FileDownloader(source: source, destination: testDirectory)
        
        // Create destination with file that has different size than metadata
        let destination = downloader.destination
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        
        // Create file with actual size
        let fileData = "test content".data(using: .utf8)!
        let fileURL = destination.appendingPathComponent("model.safetensors")
        try fileData.write(to: fileURL)
        
        // Create metadata with different size
        let metadata = FilesMetadata(files: [
            FilesMetadata.FileMetadata(name: "model.safetensors", size: fileData.count + 100) // Wrong size
        ])
        try metadata.save(to: destination)
        
        // File size doesn't match metadata, should not be downloaded
        #expect(!downloader.isDownloaded)
    }
    
    @Test
    func testIsDownloadedWithEmptyMetadata() throws {
        let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("FileDownloaderTests_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testDirectory) }
        
        let globs: Globs = ["*.safetensors"]
        let source = FileDownloader.Source.huggingFace(id: "test-org/test-repo", globs: globs)
        let downloader = FileDownloader(source: source, destination: testDirectory)
        
        // Create destination with empty metadata
        let destination = downloader.destination
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        
        // Create empty metadata
        let metadata = FilesMetadata(files: [])
        try metadata.save(to: destination)
        
        // Empty metadata means all required files are present (none required)
        #expect(downloader.isDownloaded)
    }
    
    @Test
    func testRemoveMetadata() throws {
        let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("FileDownloaderTests_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testDirectory) }
        
        let globs: Globs = ["*.safetensors"]
        let source = FileDownloader.Source.huggingFace(id: "test-org/test-repo", globs: globs)
        let downloader = FileDownloader(source: source, destination: testDirectory)
        
        // Create destination with metadata
        let destination = downloader.destination
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        
        // Create metadata file
        let metadata = FilesMetadata(files: [
            FilesMetadata.FileMetadata(name: "model.safetensors", size: 100)
        ])
        try metadata.save(to: destination)
        
        // Verify metadata exists
        let metadataURL = destination.appendingPathComponent(FilesMetadata.filename)
        #expect(FileManager.default.fileExists(atPath: metadataURL.path))
        
        // Remove metadata
        try downloader.removeMetadata()
        
        // Verify metadata is removed
        #expect(!FileManager.default.fileExists(atPath: metadataURL.path))
    }
    
    @Test
    func testRemoveMetadataWhenDoesNotExist() throws {
        let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("FileDownloaderTests_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testDirectory) }
        
        let globs: Globs = ["*.safetensors"]
        let source = FileDownloader.Source.huggingFace(id: "test-org/test-repo", globs: globs)
        let downloader = FileDownloader(source: source, destination: testDirectory)
        
        // Try to remove non-existent metadata - should throw error
        #expect(throws: Error.self) {
            try downloader.removeMetadata()
        }
    }
    
    @Test
    func testBackgroundDownloadConfiguration() {
        let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("FileDownloaderTests_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testDirectory) }
        
        let globs: Globs = ["*.safetensors"]
        let source = FileDownloader.Source.huggingFace(id: "test-org/test-repo", globs: globs)
        
        // Test background configuration
        let backgroundConfig = FileDownloader.DownloadConfiguration.background(withIdentifier: "com.test.download")
        let downloader = FileDownloader(source: source, destination: testDirectory, configuration: backgroundConfig)
        
        #expect(downloader.source == source)
        
        // Test default configuration
        let defaultDownloader = FileDownloader(source: source, destination: testDirectory)
        #expect(defaultDownloader.source == source)
    }
    
    @Test
    func testDefaultRootDestination() {
        // Verify default root destination is properly set
        let defaultDestination = FileDownloader.defaultRootDestination
        
        // On macOS, it should be in home directory
        // On iOS, it should be in documents directory
        #if os(macOS) || os(Linux)
        // Should be a subdirectory in home directory
        #expect(defaultDestination.path.contains(FileManager.default.homeDirectoryForCurrentUser.path))
        #expect(defaultDestination.lastPathComponent == ".localllmclient")
        #else
        // Should be in documents directory
        #expect(defaultDestination.path.contains(URL.documentsDirectory.path))
        #expect(defaultDestination.lastPathComponent == ".localllmclient")
        #endif
    }
    
    @Test
    func testSourceEquality() {
        let globs1: Globs = ["*.safetensors", "*.json"]
        let globs2: Globs = ["*.safetensors", "*.json"]
        let globs3: Globs = ["*.bin"]
        
        let source1 = FileDownloader.Source.huggingFace(id: "test-org/test-repo", globs: globs1)
        let source2 = FileDownloader.Source.huggingFace(id: "test-org/test-repo", globs: globs2)
        let source3 = FileDownloader.Source.huggingFace(id: "test-org/test-repo", globs: globs3)
        let source4 = FileDownloader.Source.huggingFace(id: "other-org/other-repo", globs: globs1)
        
        // Same id and globs should be equal
        #expect(source1 == source2)
        
        // Different globs should not be equal
        #expect(source1 != source3)
        
        // Different id should not be equal
        #expect(source1 != source4)
    }
    
    @Test
    func testDestinationPath() {
        let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("FileDownloaderTests_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testDirectory) }
        
        let globs: Globs = ["*.safetensors"]
        let source = FileDownloader.Source.huggingFace(id: "test-org/test-repo", globs: globs)
        let downloader = FileDownloader(source: source, destination: testDirectory)
        
        // Verify destination path structure
        let destination = downloader.destination
        #expect(destination.pathComponents.contains("huggingface"))
        #expect(destination.pathComponents.contains("models"))
        #expect(destination.pathComponents.contains("test-org"))
        #expect(destination.lastPathComponent == "test-repo")
    }
}
