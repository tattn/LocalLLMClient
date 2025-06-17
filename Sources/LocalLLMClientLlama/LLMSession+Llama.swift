import LocalLLMClient
import LocalLLMClientUtility
import Foundation

public extension LLMSession.DownloadModel {
    static func llama(
        id: String,
        model: String,
        mmproj: String? = nil,
        parameter: LlamaClient.Parameter = .default
    ) -> LLMSession.DownloadModel {
        var globs: Globs = [model]
        if let mmproj {
            globs.append(mmproj)
        }
        let source = FileDownloader.Source.huggingFace(id: id, globs: globs)
        let destination = source.destination(for: URL.defaultRootDirectory)
        return LLMSession.DownloadModel(
            source: source,
            makeClient: {
                try await AnyLLMClient(
                    LocalLLMClient.llama(
                        url: destination.appending(component: model),
                        mmprojURL: mmproj.map { destination.appending(component: $0) },
                        parameter: parameter,
                        verbose: false
                    )
                )
            }
        )
    }
}


