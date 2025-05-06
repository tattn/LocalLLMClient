import Foundation

extension URL {
#if os(macOS)
    static let defaultRootDirectory = URL.downloadsDirectory.appending(path: "localllmclient").excludedFromBackup
#else
    static let defaultRootDirectory = URL.documentsDirectory.appending(path: "localllmclient").excludedFromBackup
#endif

    var excludedFromBackup: URL {
        var url = self
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? url.setResourceValues(resourceValues)
        return url
    }
}
