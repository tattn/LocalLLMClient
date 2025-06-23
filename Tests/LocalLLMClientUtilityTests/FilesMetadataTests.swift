import Foundation
import Testing
@testable import LocalLLMClientUtility

struct FilesMetadataTests {
    @Test
    func testFilesMetadataSaveAndLoad() throws {
        // Create a temporary directory for testing
        let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("FilesMetadataTests")
        try? FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        
        // Create test metadata
        let fileMetadata1 = FilesMetadata.FileMetadata(name: "test1.json", size: 1024)
        let fileMetadata2 = FilesMetadata.FileMetadata(name: "test2.safetensors", size: 2048)
        let metadata = FilesMetadata(files: [fileMetadata1, fileMetadata2])
        
        // Save metadata to the test directory
        try metadata.save(to: testDirectory)
        defer {
            try? FileManager.default.removeItem(at: testDirectory)
        }

        // Verify metadata file was created
        let metadataFilePath = testDirectory.appendingPathComponent(FilesMetadata.filename)
        #expect(FileManager.default.fileExists(atPath: metadataFilePath.path))
        
        // Load metadata from the test directory
        let loadedMetadata = try FilesMetadata.load(from: testDirectory)
        
        // Verify loaded metadata matches what was saved
        #expect(loadedMetadata.files.count == 2)
        #expect(loadedMetadata.files[0].name == "test1.json")
        #expect(loadedMetadata.files[0].size == 1024)
        #expect(loadedMetadata.files[1].name == "test2.safetensors")
        #expect(loadedMetadata.files[1].size == 2048)
    }
    
    @Test
    func testHuggingFaceGlobsMLXDefault() {
        let mlxGlobs = Globs.mlx

        #expect(mlxGlobs.rawValue.count == 2)
        #expect(mlxGlobs.rawValue.contains("*.safetensors"))
        #expect(mlxGlobs.rawValue.contains("*.json"))
    }
}
