import Foundation
import Testing
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import LocalLLMClientUtility

struct HuggingFaceAPITests {
    
    /// Creates a mock session configuration with MockURLProtocol
    private func mockSessionConfiguration() -> HuggingFaceAPI.DownloadConfiguration {
        var configuration = HuggingFaceAPI.DownloadConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]
        return configuration
    }
    
    /// Creates a background session configuration with MockURLProtocol
    private func mockBackgroundSessionConfiguration() -> HuggingFaceAPI.DownloadConfiguration {
        var configuration = HuggingFaceAPI.DownloadConfiguration.background(withIdentifier: "com.\(#function)")
        configuration.protocolClasses = [MockURLProtocol.self]
        return configuration
    }
    
    /// Helper function to create a temporary directory for test file downloads
    private func createTemporaryDirectory() -> URL {
        let tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "HuggingFaceAPITests_\(UUID().uuidString)",
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
    
    @Test(.disabled(if: canImportFoundationNetworking))
    func testDownloadSnapshotWithDefaultConfiguration() async throws {
        // Setup the mock responses
        let repoInfo = """
        {
            "siblings": [
                {"rfilename": "test1.bin", "size": 1024},
                {"rfilename": "test2.bin", "size": 2048}
            ]
        }
        """
        let repoInfoData = repoInfo.data(using: .utf8)!
        let testFile1Data = "Test file 1 content".data(using: .utf8)!
        let testFile2Data = "Test file 2 content".data(using: .utf8)!
        
        let apiURL = URL(string: "https://huggingface.co/api/models/\(#function)/revision/main?blobs=true")!
        let file1URL = URL(string: "https://huggingface.co/\(#function)/resolve/main/test1.bin")!
        let file2URL = URL(string: "https://huggingface.co/\(#function)/resolve/main/test2.bin")!

        MockURLProtocol.setResponse(for: apiURL, with: repoInfoData)
        MockURLProtocol.setResponse(for: file1URL, with: testFile1Data)
        MockURLProtocol.setResponse(for: file2URL, with: testFile2Data)
        
        defer {
            MockURLProtocol.removeResponse(for: apiURL)
            MockURLProtocol.removeResponse(for: file1URL)
            MockURLProtocol.removeResponse(for: file2URL)
        }
        
        // Create a temporary directory for downloads
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        // Setup the HuggingFaceAPI client
        let repo = HuggingFaceAPI.Repo(id: #function)
        let api = HuggingFaceAPI(repo: repo)

        var progressFractionCompleted: Double = 0
        
        // Download with default configuration
        let destination = try await api.downloadSnapshot(
            to: tempDir,
            matching: Globs(["*.bin"]),
            configuration: mockSessionConfiguration()
        ) { progress in
                await MainActor.run {
                    progressFractionCompleted = progress.fractionCompleted
                }
            }

        // Verify the files were downloaded
        let file1Path = destination.appendingPathComponent("test1.bin")
        let file2Path = destination.appendingPathComponent("test2.bin")
        
        #expect(FileManager.default.fileExists(atPath: file1Path.path))
        #expect(FileManager.default.fileExists(atPath: file2Path.path))
        
        let file1Content = try String(contentsOf: file1Path, encoding: .utf8)
        let file2Content = try String(contentsOf: file2Path, encoding: .utf8)
        
        #expect(file1Content == "Test file 1 content")
        #expect(file2Content == "Test file 2 content")
        #expect(progressFractionCompleted == 1.0)
    }
}
