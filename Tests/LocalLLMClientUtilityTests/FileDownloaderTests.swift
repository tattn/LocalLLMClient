import Foundation
import Testing
@testable import LocalLLMClientUtility

struct FileDownloaderTests {
    @Test
    func testFileDownloaderInitialization() async throws {
        // Create a temporary test directory
        let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("FileDownloaderTests")
        try? FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: testDirectory)
        }

        // Initialize a FileDownloader with Hugging Face source
        let globs: FileDownloader.Source.HuggingFaceGlobs = ["*.safetensors", "*.json"]
        let source = FileDownloader.Source.huggingFace(id: "test-repo", globs: globs)
        let downloader = FileDownloader(source: source, destination: testDirectory)
        
        // Verify the initialization
        #expect(downloader.source == source)
        #expect(downloader.destination.pathComponents[(downloader.destination.pathComponents.count - 4)...] == ["FileDownloaderTests", "huggingface", "models", "test-repo"])
    }
}
