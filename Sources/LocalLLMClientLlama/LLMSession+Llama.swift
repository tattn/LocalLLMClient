import LocalLLMClientCore
import LocalLLMClientUtility
import Foundation

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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
            makeClient: { tools in
                try await AnyLLMClient(
                    LocalLLMClient.llama(
                        url: destination.appending(component: model),
                        mmprojURL: mmproj.map { destination.appending(component: $0) },
                        parameter: parameter,
                        tools: tools.map { $0.underlyingTool }
                    )
                )
            }
        )
    }
}


