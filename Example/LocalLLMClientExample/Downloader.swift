import SwiftUI
import LocalLLMClientUtility

struct Downloader: Sendable {
    init(model: LLMModel) {
        self.model = model
        let globs: FileDownloader.Source.HuggingFaceGlobs = switch model {
        case .qwen3, .qwen3_4b: .mlx
        case .gemma3, .gemma3_4b: [model.filename]
        }
#if os(macOS)
        downloader = FileDownloader(source: .huggingFace(id: model.id, globs: globs))
#elseif os(iOS)
        downloader = BackgroundFileDownloader(source: .huggingFace(id: model.id, globs: globs))
#endif
    }

    private let model: LLMModel
#if os(macOS)
    private let downloader: FileDownloader
#elseif os(iOS)
    private let downloader: BackgroundFileDownloader
#endif

    var url: URL {
        downloader.destination.appending(component: model.filename)
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
