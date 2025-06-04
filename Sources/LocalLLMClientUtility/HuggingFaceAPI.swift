import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Represents the Hugging Face API client
public struct HuggingFaceAPI: Sendable {
    /// API endpoint for Hugging Face Hub
    private let endpoint = URL(string: "https://huggingface.co")!

    /// Authentication token for accessing Hugging Face Hub
    public let hfToken: String?
    
    /// Repository reference for Hugging Face
    public let repo: Repo
    
    /// Initializes a new Hugging Face API client
    /// - Parameters:
    ///   - repo: Repository information
    ///   - token: Authentication token (optional)
    public init(repo: Repo, token: String? = nil) {
        self.repo = repo
        self.hfToken = token
    }

    /// Repository type for Hugging Face repositories
    public enum RepoType: String, Sendable {
        case models
        case datasets
        case spaces
    }

    /// Repository information for Hugging Face
    public struct Repo: Equatable, Sendable {
        /// Repository identifier, such as "meta-llama/Meta-Llama-3-8B"
        public let id: String

        /// Repository type, defaults to models
        public let type: RepoType

        /// Creates a new repository reference
        /// - Parameters:
        ///   - id: Repository identifier
        ///   - type: Repository type, defaults to `.models`
        public init(id: String, type: RepoType = .models) {
            self.id = id
            self.type = type
        }
    }

    public struct DownloadConfiguration: Sendable {
        public var identifier: String?
        public var protocolClasses: [AnyClass]?

        /// Initializes a new download configuration
        public static let `default` = DownloadConfiguration(identifier: nil)

        /// Creates a new download configuration for background downloads
        public static func background(withIdentifier identifier: String) -> DownloadConfiguration {
            DownloadConfiguration(identifier: identifier)
        }

        func makeURLSessionConfiguration() -> URLSessionConfiguration {
            let config: URLSessionConfiguration
            if let identifier {
                config = URLSessionConfiguration.background(withIdentifier: identifier)
                config.isDiscretionary = true
                config.sessionSendsLaunchEvents = true
            } else {
                config = .default
            }
            config.protocolClasses = protocolClasses
            return config
        }
    }

    /// Get the local directory location for a repository
    /// - Parameters:
    ///   - downloadBase: The base directory for downloads
    /// - Returns: The local URL for the repository
    public func getLocalRepoLocation(downloadBase: URL) -> URL {
        downloadBase
            .appending(component: "huggingface")
            .appending(component: repo.type.rawValue)
            .appending(component: repo.id)
    }

    /// Retrieves filenames from a Hugging Face repository that match the given glob patterns
    /// - Parameters:
    ///   - globs: Array of glob patterns to match files (e.g., "*.json")
    ///   - revision: The repository revision (branch, tag, or commit hash), defaults to "main"
    /// - Returns: Array of matching filenames
    public func getFilenames(
        matching globs: Globs,
        revision: String = "main",
        configuration: URLSessionConfiguration = .default
    ) async throws -> [String] {
        // Read repo info and only parse "siblings" (files in the repository)
        let (data, _) = try await get(
            for: endpoint.appending(path: "api/\(repo.type.rawValue)/\(repo.id)/revision/\(revision)"),
            configuration: configuration
        )

        // Decode the JSON response
        let response = try JSONDecoder().decode(SiblingsResponse.self, from: data)
        let filenames = response.siblings.map(\.rfilename)

        // If no globs are provided, return all filenames
        guard !globs.rawValue.isEmpty else { return filenames }
        
        // Filter filenames based on glob patterns
        var selected: Set<String> = []
        for glob in globs.rawValue {
            selected = selected.union(filenames.matching(glob: glob))
        }
        
        return Array(selected)
    }

    /// Downloads files from a Hugging Face repository that match the given glob patterns
    /// - Parameters:
    ///   - downloadBase: The base directory for downloads
    ///   - globs: Array of glob patterns to match files (e.g., "*.json")
    ///   - revision: The repository revision (branch, tag, or commit hash), defaults to "main"
    ///   - configuration: URLSession configuration to use for the download, defaults to .default
    ///   - progressHandler: Closure to report download progress
    /// - Returns: The local URL where files were downloaded
    @discardableResult
    public func downloadSnapshot(
        to downloadBase: URL,
        matching globs: Globs,
        revision: String = "main",
        configuration: DownloadConfiguration = .default,
        progressHandler: @Sendable @escaping (Progress) async -> Void = { _ in }
    ) async throws -> URL {
        let destination = getLocalRepoLocation(downloadBase: downloadBase)

        // Create the directory structure
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        // Get filenames to download
        let filenames = try await getFilenames(matching: globs, revision: revision, configuration: configuration.makeURLSessionConfiguration())

        let downloader = Downloader()
        for filename in filenames {
            let type = repo.type == .models ? "" : "\(repo.type.rawValue)/"
            downloader.add(.init(
                url: endpoint.appending(path: "\(type)\(repo.id)/resolve/\(revision)/\(filename)"),
                destinationURL: destination.appendingPathComponent(filename),
                configuration: {
                    if let identifier = configuration.identifier {
                        var configuration = configuration
                        configuration.identifier = "\(identifier)_\(filename)"
                        return configuration.makeURLSessionConfiguration()
                    } else {
                        return configuration.makeURLSessionConfiguration()
                    }
                }()
            ))
        }
        downloader.setObserver { progress in
            await progressHandler(progress)
        }

        try await downloader.downloadAndAwait()

        return destination
    }
    
    /// Gets metadata for a file in a Hugging Face repository
    /// - Parameters:
    ///   - url: The URL of the file
    /// - Returns: The file metadata
    public func getFileMetadata(url: URL) async throws -> FileMetadata {
        let (_, response) = try await get(for: url)
        let location = response.statusCode == 302 ? response.value(forHTTPHeaderField: "Location") : response.url?.absoluteString
        
        return FileMetadata(
            commitHash: response.value(forHTTPHeaderField: "X-Repo-Commit"),
            etag: normalizeEtag(response.value(forHTTPHeaderField: "ETag")),
            location: location ?? url.absoluteString,
            size: Int(response.value(forHTTPHeaderField: "Content-Length") ?? "")
        )
    }
    
    private func normalizeEtag(_ etag: String?) -> String? {
        guard let etag else { return nil }
        return etag.trimmingPrefix("W/").trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
    
    /// Gets metadata for files in a Hugging Face repository that match the given glob patterns
    /// - Parameters:
    ///   - globs: Array of glob patterns to match files (e.g., "*.json")
    ///   - revision: The repository revision (branch, tag, or commit hash), defaults to "main"
    /// - Returns: Array of file metadata
    public func getFileMetadata(matching globs: Globs, revision: String = "main") async throws -> [FileMetadata] {
        let files = try await getFilenames(matching: globs, revision: revision)
        let baseURL = URL(string: "\(endpoint)/\(repo.type.rawValue)/\(repo.id)/resolve/\(revision)")!
        
        var metadata: [FileMetadata] = []
        for file in files {
            let fileURL = baseURL.appendingPathComponent(file)
            try await metadata.append(getFileMetadata(url: fileURL))
        }
        
        return metadata
    }
    
    /// Data structure containing information about a file versioned on the Hub
    public struct FileMetadata {
        /// The commit hash related to the file
        public let commitHash: String?
        
        /// Etag of the file on the server
        public let etag: String?
        
        /// Location where to download the file. Can be a Hub url or not (CDN).
        public let location: String
        
        /// Size of the file. In case of an LFS file, contains the size of the actual LFS file, not the pointer.
        public let size: Int?
    }
}

// MARK: - API Helpers

extension HuggingFaceAPI {
    private struct SiblingsResponse: Codable {
        let siblings: [Sibling]

        /// Model data for parsed filenames
        struct Sibling: Codable {
            let rfilename: String
        }
    }
    
    /// Performs an HTTP GET request to the specified URL
    /// - Parameter url: The URL to request
    /// - Returns: Tuple containing the response data and HTTP response
    private func get(for url: URL, configuration: URLSessionConfiguration = .default) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        if let hfToken {
            request.setValue("Bearer \(hfToken)", forHTTPHeaderField: "Authorization")
        }

        var configuration = configuration
        if configuration.identifier != nil {
            let foregroundConfiguration = URLSessionConfiguration.default
            foregroundConfiguration.protocolClasses = configuration.protocolClasses
            configuration = foregroundConfiguration
        }

        let (data, response) = try await URLSession(configuration: configuration).data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        switch httpResponse.statusCode {
        case 200..<400:
            return (data, httpResponse)
        case 401, 403:
            throw URLError(.userAuthenticationRequired)
        case 404:
            throw URLError(.fileDoesNotExist)
        default:
            throw URLError(.badServerResponse)
        }
    }
}

private extension [String] {
    /// Filters the array to only include strings that match the specified glob pattern
    /// - Parameter glob: The glob pattern to match against
    /// - Returns: Array of strings that match the glob pattern
    func matching(glob: String) -> [String] {
        filter { fnmatch(glob, $0, 0) == 0 }
    }
}
