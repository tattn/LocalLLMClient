import LocalLLMClient
import LocalLLMClientUtility
import Foundation

public extension LLMSession.Model {
    static func mlx(
        id: String,
        parameter: MLXClient.Parameter = .default
    ) -> LLMSession.DownloadModel {
        let source = FileDownloader.Source.huggingFace(id: id, globs: .mlx)
        return LLMSession.DownloadModel(
            source: source,
            makeClient: {
                try await AnyLLMClient(
                    LocalLLMClient.mlx(url: source.destination(for: URL.defaultRootDirectory), parameter: parameter)
                )
            }
        )
    }
}
