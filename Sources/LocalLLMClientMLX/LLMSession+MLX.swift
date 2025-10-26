import LocalLLMClientCore
import LocalLLMClientUtility
import Foundation

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public extension LLMSession.DownloadModel {
    static func mlx(
        id: String,
        destination: URL? = nil,
        parameter: MLXClient.Parameter = .default
    ) -> LLMSession.DownloadModel {
        .mlx(
            source: FileDownloader.Source.huggingFace(id: id, globs: .mlx),
            destination: destination,
            parameter: parameter
        )
    }

    static func mlx(
        source: FileDownloader.Source,
        destination: URL? = nil,
        parameter: MLXClient.Parameter = .default
    ) -> LLMSession.DownloadModel {
        let rootDestination = destination ?? URL.defaultRootDirectory
        return LLMSession.DownloadModel(
            source: source,
            destination: rootDestination,
            makeClient: { tools in
                try await AnyLLMClient(
                    LocalLLMClient.mlx(url: source.destination(for: rootDestination), parameter: parameter, tools: tools.map { $0.underlyingTool })
                )
            }
        )
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public extension LLMSession.LocalModel {
    /// Create an MLX model from local file path
    static func mlx(
        url: URL,
        parameter: MLXClient.Parameter = .default
    ) -> LLMSession.LocalModel {
        return LLMSession.LocalModel(
            modelPath: url,
            makeClient: { tools in
                try await AnyLLMClient(
                    LocalLLMClient.mlx(url: url, parameter: parameter, tools: tools.map { $0.underlyingTool })
                )
            }
        )
    }
}
