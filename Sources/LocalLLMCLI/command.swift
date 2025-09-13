#if os(Linux)
// Workaround: https://github.com/swiftlang/swift/issues/77866
@preconcurrency import var Glibc.stdout
#endif
import ArgumentParser
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import LocalLLMClientCore
import LocalLLMClientLlama
#if canImport(LocalLLMClientMLX)
import LocalLLMClientMLX
#endif
#if canImport(LocalLLMClientFoundationModels)
import LocalLLMClientFoundationModels
#endif
#if canImport(LocalLLMClientUtility)
import LocalLLMClientUtility
#endif

@main
struct LocalLLMCommand: AsyncParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
        commandName: "localllm",
        abstract: "A command line tool for interacting with local LLMs",
        discussion: """
            Run LLM models directly from your command line.
            """
    )

    @Option(name: [.short, .long], help: "Path to the model file")
    var model: String = ""

    @Option(name: [.short, .long], help: "Backend to use: \(Backend.allCases.map(\.rawValue).joined(separator: ", "))")
    var backend: String = Backend.llama.rawValue

    @Option(name: [.short, .long], help: "Temperature for sampling")
    var temperature: Float = 0.8

    @Option(name: [.customShort("p"), .long], help: "Top-p for sampling")
    var topP: Float = 0.9

    @Option(name: [.customShort("k"), .long], help: "Top-k for sampling")
    var topK: Int = 40

    @Option(name: [.long], help: "Path to the mmproj")
    var mmproj: String?
    @Option(name: [.customLong("image")], help: "Path to the image file")
    var imageURL: String?

    @Flag(name: [.customShort("v"), .long], help: "Show verbose output")
    var verbose: Bool = false

    @Argument(help: "The prompt to send to the model")
    var prompt: String

    enum Backend: String, CaseIterable {
        case llama
        case mlx
        case foundationModels = "foundation-models"
    }

    func run() async throws {
        let backend = Backend(rawValue: backend) ?? .llama
        log("Loading model from: \(model) with backend: \(backend.rawValue)")

        // Initialize client
        let client: any LLMClient
        switch backend {
        case .llama:
            client = try await LocalLLMClient.llama(
                url: getModel(for: model, backend: backend),
                mmprojURL: mmproj.asyncMap { try await getModel(for: $0, backend: backend) },
                parameter: .init(
                    temperature: temperature,
                    topK: topK,
                    topP: topP,
                    options: .init(verbose: verbose)
                )
            )
        case .mlx:
#if canImport(LocalLLMClientMLX)
            client = try await LocalLLMClient.mlx(
                url: getModel(for: model, backend: backend),
                parameter: .init(
                    temperature: temperature,
                    topP: topP,
                )
            )
#else
            throw LocalLLMCommandError.invalidModel("MLX backend is not supported on this platform.")
#endif
        case .foundationModels:
#if canImport(FoundationModels)
            if #available(macOS 26.0, iOS 26.0, *) {
                client = try await LocalLLMClient.foundationModels(
                    parameter: .init(
                        temperature: Double(temperature)
                    )
                )
            } else {
                throw LocalLLMCommandError.invalidModel("FoundationModels backend is not supported on this environment.")
            }
#else
            throw LocalLLMCommandError.invalidModel("FoundationModels backend is not supported on this environment.")
#endif
        }

        var attachments: [LLMAttachment] = []
        if let imageURL {
            attachments.append(.image(LLMInputImage(data: try Data(contentsOf: URL(filePath: imageURL)))!))
        }

        log("Generating response for prompt: \"\(prompt)\"")
        log("---")

        let input = LLMInput(
            .chat([.user(prompt, attachments: attachments)]),
        )

        // Generate response
        for try await token in try await client.textStream(from: input) {
            print(token, terminator: "")
            fflush(stdout)
        }

        log("\n---")
        log("Generation complete.")
    }

    private func getModel(for model: String, backend: Backend) async throws -> URL {
        return if model.hasPrefix("/") {
            URL(filePath: model)
        } else if model.hasPrefix("https://"), let url = URL(string: model) {
            try await downloadModel(from: url, backend: backend)
        } else if model.isEmpty {
            throw LocalLLMCommandError.invalidModel("Error: Missing expected argument '--model <model>'")
        } else {
            throw LocalLLMCommandError.invalidModel(model)
        }
    }

    private func downloadModel(from url: URL, backend: Backend) async throws -> URL {
        #if canImport(LocalLLMClientUtility)
        log("Downloading model from Hugging Face: \(model)")

        let globs: Globs = switch backend {
        case .llama: .init(["*\(url.lastPathComponent)"])
        case .mlx: .mlx
        case .foundationModels: []
        }

        let downloader = FileDownloader(source: .huggingFace(
            id: url.pathComponents[1...2].joined(separator: "/"),
            globs: globs
        ))
        try await downloader.download { progress in
            log("Downloading model: \(progress)")
        }
        return switch backend {
        case .llama: downloader.destination.appendingPathComponent(url.lastPathComponent)
        case .mlx: downloader.destination
        case .foundationModels: throw LocalLLMCommandError.invalidModel("Model downloading is not applicable for the FoundationModels backend.")
        }
        #else
        throw LocalLLMCommandError.invalidModel("Downloading models is not supported on this platform.")
        #endif
    }

    private func log(_ message: String) {
        if verbose {
            print(message)
        }
    }
}

enum LocalLLMCommandError: Error {
    case invalidModel(String)
}
