import Foundation

package extension FileManager {
    func removeEmptyDirectories(in url: URL) throws {
        guard url.isFileURL else { return }

        let contents = try contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
        let subdirectories = try contents.filter { try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false }

        for subdirectory in subdirectories { try removeEmptyDirectories(in: subdirectory) }

        guard try contentsOfDirectory(at: url, includingPropertiesForKeys: nil).isEmpty else { return }

        try removeItem(at: url)
    }

    func removeAllItems(in url: URL, excludingURLs: [URL] = [], removingEmptyDirectories: Bool = true) throws {
        guard let enumerator = enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsPackageDescendants]) else { return }

        let excludingURLsNormalized: Set<URL> = Set(excludingURLs.map { $0.resolvingSymlinksInPath().standardizedFileURL
        })

        for case let fileURL as URL in enumerator {
            if excludingURLsNormalized.contains(fileURL.resolvingSymlinksInPath().standardizedFileURL) {
                enumerator.skipDescendants()
                continue
            }

            if (try fileURL.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == false {
                try removeItem(at: fileURL)
            }
        }

        if removingEmptyDirectories { try removeEmptyDirectories(in: url) }
    }
}
