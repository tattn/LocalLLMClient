import Foundation
import Testing
@testable import LocalLLMClientUtility

struct URLExtensionTests {
    @Test
    func testDefaultRootDirectory() {
        let url = URL.defaultRootDirectory
        
        #if os(macOS)
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        #expect(url.path.hasPrefix(homeDir.path))
        #expect(url.path.contains("/.localllmclient"))
        #elseif os(iOS)
        let docsDir = URL.documentsDirectory
        #expect(url.path.hasPrefix(docsDir.path))
        #expect(url.path.contains("/.localllmclient"))
        #endif
    }

#if !os(Linux)
    @Test
    func testExcludedFromBackup() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("testExcludedFromBackup")
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)

        // Apply the excludedFromBackup property
        let excludedURL = tempURL.excludedFromBackup
        
        // Check if the resource value is set correctly
        let resourceValues = try excludedURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        let isExcluded = resourceValues.isExcludedFromBackup ?? false

        #expect(isExcluded, "URL should be excluded from backup")
    }
#endif
}
