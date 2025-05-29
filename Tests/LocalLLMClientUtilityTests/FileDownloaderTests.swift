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
}
