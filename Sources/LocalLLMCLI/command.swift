import ArgumentParser
import Foundation
import LocalLLMClient
import LocalLLMClientLlama
import LocalLLMClientMLX
import LocalLLMClientUtility

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
    var model: String

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
    }

    func run() async throws {
        let backend = Backend(rawValue: backend) ?? .llama
        log("Loading model from: \(model) with backend: \(backend.rawValue)")

        let modelURL = try await getModel(for: model, backend: backend)

        // Initialize client
        let client: any LLMClient
        switch backend {
        case .llama:
            client = try await LocalLLMClient.llama(
                url: modelURL,
                mmprojURL: mmproj.asyncMap { try await getModel(for: $0, backend: backend) },
                parameter: .init(
                    temperature: temperature,
                    topK: topK,
                    topP: topP,
                ),
                verbose: verbose
            )
        case .mlx:
            client = try await LocalLLMClient.mlx(
                url: modelURL,
                parameter: .init(
                    temperature: temperature,
                    topP: topP,
                )
            )
        }

        var attachments: [LLMAttachment] = []
        if let imageURL {
            attachments.append(.image(LLMInputImage(contentsOfFile: URL(filePath: imageURL).path())!))
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
        } else {
            throw LocalLLMCommandError.invalidModel(model)
        }
    }

    private func downloadModel(from url: URL, backend: Backend) async throws -> URL {
        log("Downloading model from Hugging Face: \(model)")

        let globs: FileDownloader.Source.HuggingFaceGlobs = switch backend {
        case .llama: .init(["*\(url.lastPathComponent)"])
        case .mlx: .mlx
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
        }
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
