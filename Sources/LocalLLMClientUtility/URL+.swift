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
}
