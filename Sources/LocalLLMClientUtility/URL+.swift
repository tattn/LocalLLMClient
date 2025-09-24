import Foundation

package extension URL {
#if os(macOS) || os(Linux)
    static let defaultRootDirectory = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".localllmclient").excludedFromBackup
#else
    static let defaultRootDirectory = URL.documentsDirectory.appending(path: ".localllmclient").excludedFromBackup
#endif

    var excludedFromBackup: URL {
#if os(Linux)
        return self
#else
        var url = self
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? url.setResourceValues(resourceValues)
        return url
#endif
    }

    func removeEmptyFolders() throws {
        guard isFileURL else { return }

        let contents = try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: [.isDirectoryKey])
        let subdirectories = try contents.filter { try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false }

        for subdirectory in subdirectories { try subdirectory.removeEmptyFolders() }

        guard try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil).isEmpty else { return }

        try FileManager.default.removeItem(at: self)
    }
}
