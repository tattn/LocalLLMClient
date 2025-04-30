import ArgumentParser
import Foundation
import LocalLLMClient
import LlamaSwift

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

    @Option(name: [.short, .long], help: "Temperature for sampling")
    var temperature: Float = 0.8

    @Option(name: [.customShort("p"), .long], help: "Top-p for sampling")
    var topP: Float = 0.9

    @Option(name: [.customShort("k"), .long], help: "Top-k for sampling")
    var topK: Int = 40

    @Flag(name: [.customShort("v"), .long], help: "Show verbose output")
    var verbose: Bool = false

    @Argument(help: "The prompt to send to the model")
    var prompt: String

    func run() async throws {
        setLlamaLog(callback: verbose ? { level, message in
            llamaLog(level: level, message: message)
            print(message, terminator: "")
        } : nil)

        if verbose {
            print("Loading model from: \(model)")
        }

        // Initialize client
        let parameter = LLMParameter(
            temperature: temperature,
            topK: topK,
            topP: topP,
        )
        let modelURL = URL(fileURLWithPath: model)
        let client = try LocalLLMClient.makeClient(url: modelURL, parameter: parameter)

        if verbose {
            print("Generating response for prompt: \"\(prompt)\"")
            print("---")
        }

        // Generate response
        for try await token in client.predict(prompt) {
            print(token, terminator: "")
            fflush(stdout)
        }

        if verbose {
            print("\n---")
            print("Generation complete.")
        } else {
            print("")
        }
    }
}
