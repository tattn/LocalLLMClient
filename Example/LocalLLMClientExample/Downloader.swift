import SwiftUI
import LocalLLMClientUtility

struct Downloader: Sendable {
    init(model: LLMModel) {
        self.model = model
        let globs: Globs = switch model {
        case .qwen3, .qwen3_4b, .qwen2_5VL_3b, .gemma3_4b_mlx: .mlx
        case .phi4mini, .gemma3, .gemma3_4b, .mobileVLM_3b: .init(
            (model.filename.map { [$0] } ?? []) + (model.mmprojFilename.map { [$0] } ?? [])
        )}
#if os(macOS)
        downloader = FileDownloader(source: .huggingFace(id: model.id, globs: globs))
#elseif os(iOS)
        downloader = FileDownloader(
            source: .huggingFace(id: model.id, globs: globs),
            configuration: .background(withIdentifier: "localllmclient.downloader.\(model.id)")
        )
#endif
        // try? downloader.removeMetadata() // use it if you update the models
    }

    private let model: LLMModel
    private let downloader: FileDownloader

    var url: URL {
        downloader.destination.appending(component: model.filename ?? "")
    }

    var clipURL: URL? {
        model.mmprojFilename.map { downloader.destination.appending(component: $0) }
    }

    var isDownloaded: Bool {
        downloader.isDownloaded
    }

    func download(progressHandler: @escaping @Sendable (Double) async -> Void) async throws {
        try await downloader.download { progress in
            await progressHandler(progress)
        }
    }
}
