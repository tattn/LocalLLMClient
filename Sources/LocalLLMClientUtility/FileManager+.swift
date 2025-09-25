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
}
