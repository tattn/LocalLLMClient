import LocalLLMClientCore
import LocalLLMClientUtility
import Foundation

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public extension LLMSession.DownloadModel {
    static func mlx(
        id: String,
        parameter: MLXClient.Parameter = .default
    ) -> LLMSession.DownloadModel {
        let source = FileDownloader.Source.huggingFace(id: id, globs: .mlx)
        return LLMSession.DownloadModel(
            source: source,
            makeClient: { tools in
                try await AnyLLMClient(
                    LocalLLMClient.mlx(url: source.destination(for: URL.defaultRootDirectory), parameter: parameter, tools: tools.map { $0.underlyingTool })
                )
            }
        )
    }
}
