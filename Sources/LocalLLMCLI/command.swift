import ArgumentParser

@main
struct LocalLLMCommand: AsyncParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
        commandName: "localllm",
        abstract: "A command line tool for interacting with local LLMs",
        discussion: """
            Run LLM models directly from your command line.
            
            Examples:
              # Run a single prompt
              localllm run --model /path/to/model.gguf "What is 2+2?"
              
              # Run benchmarks
              localllm benchmark --model /path/to/model.gguf --mode basic
              localllm benchmark --model /path/to/model.gguf --mode context --iterations 5
            """,
        subcommands: [RunCommand.self, BenchmarkCommand.self],
        defaultSubcommand: RunCommand.self
    )
}
