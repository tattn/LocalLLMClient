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
        let source = FileDownloader.Source.huggingFace(id: id, globs: .mlx)
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
