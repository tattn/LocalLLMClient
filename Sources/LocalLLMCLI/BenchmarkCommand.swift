// ## Basic benchmark (tests with a single prompt)
// swift run -c release LocalLLMCLI benchmark --model ~/.localllmclient/huggingface/models/lmstudio-community/gemma-3-4B-it-qat-GGUF/gemma-3-4B-it-QAT-Q4_0.gguf --output ~/Desktop/results.json
//
// ## Basic benchmark with custom prompt
// swift run LocalLLMCLI benchmark --model /path/to/model.gguf --prompt "Your custom prompt here"
//
// ## Context size benchmark (tests with different context sizes: 512, 1024, 2048)
// swift run LocalLLMCLI benchmark --model /path/to/model.gguf --mode context
//
// ## Batch size benchmark (tests with different batch sizes: 1, 8, 32, 64)
// swift run LocalLLMCLI benchmark --model /path/to/model.gguf --mode batch
//
// ## Run all benchmarks with custom prompt
// swift run LocalLLMCLI benchmark --model /path/to/model.gguf --mode all --prompt "Custom prompt for all tests"
//
// ## Custom iterations (default is 3)
// swift run LocalLLMCLI benchmark --model /path/to/model.gguf --mode basic --iterations 10
//
// ## Custom context sizes (comma-separated)
// swift run LocalLLMCLI benchmark --model /path/to/model.gguf --mode context --context 256,512,1024,2048,4096
//
// ## Custom batch sizes (comma-separated)
// swift run LocalLLMCLI benchmark --model /path/to/model.gguf --mode batch --batch 1,4,16,32,64,128
//
// ## Download model from HuggingFace and run benchmark
// swift run LocalLLMCLI benchmark --model https://huggingface.co/lmstudio-community/gemma-3-4B-it-qat-GGUF/gemma-3-4B-it-QAT-Q4_0.gguf
//
// ## Verbose output for debugging
// swift run LocalLLMCLI benchmark --model /path/to/model.gguf --mode basic --verbose
//
// MARK: - Benchmark Metrics
//
// The benchmark measures the following metrics:
// - **First Token Latency (FTL)**: Time from request to first generated token (in seconds)
// - **Prompt Decoding Time (PDT)**: Time to decode/process the input prompt (in seconds)
// - **Tokens Per Second (TPS)**: Overall throughput of token generation (excludes prompt decoding time)
// - **Total Tokens**: Number of tokens generated in each iteration
//
// Results are saved as JSON files in ./tmp/ directory by default, with the following structure:
// - name: Benchmark test name
// - metrics: Array of individual test runs
// - summary: Aggregated statistics (average, min, max)
// - timestamp: When the benchmark was run

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
#if canImport(LocalLLMClientUtility)
import LocalLLMClientUtility
#endif

struct BenchmarkCommand: AsyncParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
        commandName: "benchmark",
        abstract: "Run performance benchmarks on a local LLM"
    )

    @Option(name: [.short, .long], help: "Path to the model file")
    var model: String = ""

    @Option(name: [.customLong("mode")], help: "Benchmark mode: basic, context, batch, all")
    var mode: String = "basic"

    @Option(name: [.short, .long], help: "Number of iterations per benchmark")
    var iterations: Int = 3

    @Option(name: [.short, .customLong("context")], help: "Context size for benchmarks (comma-separated for multiple)")
    var contextSizes: String = "512,1024,2048"

    @Option(name: [.short, .customLong("batch")], help: "Batch sizes for benchmarks (comma-separated for multiple)")
    var batchSizes: String = "1,8,32,64"

    @Option(name: [.customShort("o"), .long], help: "Output file for benchmark results (JSON)")
    var output: String?

    @Option(name: [.customShort("p"), .long], help: "Custom prompt for benchmarking (overrides default prompt)")
    var prompt: String?

    @Flag(name: [.customShort("v"), .long], help: "Show verbose output")
    var verbose: Bool = false

    func run() async throws {
        print("🚀 Starting benchmark for model: \(model)")
        print("Mode: \(mode), Iterations: \(iterations)")
        print("")

        var allResults: [BenchmarkResult] = []

        switch mode.lowercased() {
        case "basic":
            allResults = try await runBasicBenchmark()
        case "context":
            allResults = try await runContextBenchmark()
        case "batch":
            allResults = try await runBatchBenchmark()
        case "all":
            allResults += try await runBasicBenchmark()
            allResults += try await runContextBenchmark()
            allResults += try await runBatchBenchmark()
        default:
            throw LocalLLMCommandError.invalidModel("Unknown benchmark mode: \(mode). Use: basic, context, batch, or all")
        }

        // Print summary
        printSummary(allResults)

        // Save results
        if let output = output {
            try saveResults(allResults, to: output)
        } else {
            try saveResults(allResults)
        }
    }

    private func runBasicBenchmark() async throws -> [BenchmarkResult] {
        print("📊 Running basic benchmark...")
        let benchmarkPrompt = prompt ?? "Please write the opening of a short story set in a future Tokyo, with a cat as the main character. Make it cyberpunk-style, include vivid emotional descriptions, and craft the story so that the reader cannot predict what will happen next."

        print("  Testing with prompt: \"\(String(benchmarkPrompt.prefix(50)))...\"")
        let metrics = try await runSingleBenchmark(prompt: benchmarkPrompt, iterations: iterations)
        
        return [BenchmarkResult(
            name: "Basic benchmark",
            metrics: metrics,
            summary: calculateSummary(metrics),
            timestamp: Date()
        )]
    }

    private func runContextBenchmark() async throws -> [BenchmarkResult] {
        print("📊 Running context size benchmark...")
        let contexts = contextSizes.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        let benchmarkPrompt = prompt ?? "Explain quantum computing in detail."
        var results: [BenchmarkResult] = []

        for context in contexts {
            print("  Testing context size: \(context)")
            let metrics = try await runSingleBenchmark(
                prompt: benchmarkPrompt,
                iterations: iterations,
                context: context
            )
            results.append(BenchmarkResult(
                name: "Context \(context)",
                metrics: metrics,
                summary: calculateSummary(metrics),
                timestamp: Date()
            ))
        }
        return results
    }

    private func runBatchBenchmark() async throws -> [BenchmarkResult] {
        print("📊 Running batch size benchmark...")
        let batches = batchSizes.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        let benchmarkPrompt = prompt ?? "Explain the theory of relativity."
        var results: [BenchmarkResult] = []

        for batch in batches {
            print("  Testing batch size: \(batch)")
            let metrics = try await runSingleBenchmark(
                prompt: benchmarkPrompt,
                iterations: iterations,
                batch: batch
            )
            results.append(BenchmarkResult(
                name: "Batch \(batch)",
                metrics: metrics,
                summary: calculateSummary(metrics),
                timestamp: Date()
            ))
        }
        return results
    }

    private func runSingleBenchmark(
        prompt: String,
        iterations: Int,
        context: Int? = nil,
        batch: Int? = nil
    ) async throws -> [BenchmarkMetrics] {
        var parameter = LlamaClient.Parameter(
            temperature: 0.7,
            topP: 0.9,
            options: .init(verbose: verbose)
        )

        if let context = context {
            parameter.context = context
        }
        if let batch = batch {
            parameter.batch = batch
        }

        let modelURL = try await getModel()
        let client = try await LocalLLMClient.llama(
            url: modelURL,
            parameter: parameter
        )

        var metrics: [BenchmarkMetrics] = []

        for i in 1...iterations {
            if verbose {
                print("    Iteration \(i)/\(iterations)...")
            }

            var firstTokenLatency: TimeInterval = 0
            var promptDecodingTime: TimeInterval = 0
            var tokensGenerated = 0
            var isFirstToken = true
            let start = Date()

            let generator = try await client.textStream(from: prompt)
            promptDecodingTime = Date().timeIntervalSince(start)
            
            let generationStart = Date()
            for try await _ in generator {
                if isFirstToken {
                    firstTokenLatency = Date().timeIntervalSince(start)
                    isFirstToken = false
                }
                tokensGenerated += 1
            }

            let generationTime = Date().timeIntervalSince(generationStart)
            let totalTime = Date().timeIntervalSince(start)

            metrics.append(BenchmarkMetrics(
                firstTokenLatency: firstTokenLatency,
                promptDecodingTime: promptDecodingTime,
                tokensPerSecond: Double(tokensGenerated) / generationTime,
                totalTokens: tokensGenerated,
                totalTime: totalTime
            ))
        }

        return metrics
    }

    private func calculateSummary(_ metrics: [BenchmarkMetrics]) -> BenchmarkResult.Summary {
        let tps = metrics.map(\.tokensPerSecond)
        let ftl = metrics.map(\.firstTokenLatency)
        let pdt = metrics.map(\.promptDecodingTime)
        let tt = metrics.map(\.totalTime)

        return BenchmarkResult.Summary(
            avgTokensPerSecond: tps.reduce(0, +) / Double(tps.count),
            avgFirstTokenLatency: ftl.reduce(0, +) / Double(ftl.count),
            minFirstTokenLatency: ftl.min() ?? 0,
            maxFirstTokenLatency: ftl.max() ?? 0,
            avgPromptDecodingTime: pdt.reduce(0, +) / Double(pdt.count),
            minPromptDecodingTime: pdt.min() ?? 0,
            maxPromptDecodingTime: pdt.max() ?? 0,
            avgTotalTime: tt.reduce(0, +) / Double(tt.count),
            minTotalTime: tt.min() ?? 0,
            maxTotalTime: tt.max() ?? 0
        )
    }

    private func printSummary(_ results: [BenchmarkResult]) {
        print("\n📈 Benchmark Results Summary:")
        print(String(repeating: "=", count: 80))
        
        // Header
        let header = "\(padString("Test", to: 20)) \(padString("TPS", to: 8)) \(padString("FTL(s)", to: 8)) \(padString("PDT(s)", to: 8)) \(padString("Total(s)", to: 10))"
        print(header)
        print(String(repeating: "-", count: 90))
        
        // Results
        for result in results {
            let name = padString(result.name, to: 20)
            let tps = padString(String(format: "%.1f", result.summary.avgTokensPerSecond), to: 8)
            let ftl = padString(String(format: "%.3f", result.summary.avgFirstTokenLatency), to: 8)
            let pdt = padString(String(format: "%.3f", result.summary.avgPromptDecodingTime), to: 8)
            let tt = padString(String(format: "%.3f", result.summary.avgTotalTime), to: 10)
            print("\(name) \(tps) \(ftl) \(pdt) \(tt)")
            
            if verbose {
                let ftlMin = String(format: "%.3f", result.summary.minFirstTokenLatency)
                let ftlMax = String(format: "%.3f", result.summary.maxFirstTokenLatency)
                let pdtMin = String(format: "%.3f", result.summary.minPromptDecodingTime)
                let pdtMax = String(format: "%.3f", result.summary.maxPromptDecodingTime)
                let ttMin = String(format: "%.3f", result.summary.minTotalTime)
                let ttMax = String(format: "%.3f", result.summary.maxTotalTime)
                print("  FTL range: \(ftlMin) - \(ftlMax), PDT range: \(pdtMin) - \(pdtMax), Total range: \(ttMin) - \(ttMax)")
            }
        }
        
        print(String(repeating: "=", count: 90))
        print("TPS: Tokens Per Second, FTL: First Token Latency, PDT: Prompt Decoding Time, Total: Total Processing Time")
    }
    
    private func padString(_ str: String, to length: Int) -> String {
        if str.count >= length {
            return String(str.prefix(length))
        }
        return str + String(repeating: " ", count: length - str.count)
    }

    private func saveResults(_ results: [BenchmarkResult], to filename: String? = nil) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(results)

        let tmpDir = URL(fileURLWithPath: "./tmp")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let fileURL: URL
        if let filename = filename {
            fileURL = URL(fileURLWithPath: filename)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let filename = "benchmark_\(formatter.string(from: Date())).json"
            fileURL = tmpDir.appendingPathComponent(filename)
        }

        try jsonData.write(to: fileURL)
        print("\n💾 Results saved to: \(fileURL.path)")
    }

    private func getModel() async throws -> URL {
        if model.hasPrefix("/") {
            return URL(filePath: model)
        } else if model.hasPrefix("https://"), let url = URL(string: model) {
            return try await downloadModel(from: url)
        } else if model.isEmpty {
            throw LocalLLMCommandError.invalidModel("Error: Missing expected argument '--model <model>'")
        } else {
            throw LocalLLMCommandError.invalidModel(model)
        }
    }

    private func downloadModel(from url: URL) async throws -> URL {
        #if canImport(LocalLLMClientUtility)
        print("Downloading model from Hugging Face: \(model)")

        let downloader = FileDownloader(source: .huggingFace(
            id: url.pathComponents[1...2].joined(separator: "/"),
            globs: .init(["*\(url.lastPathComponent)"])
        ))
        try await downloader.download { progress in
            if verbose {
                print("Downloading model: \(progress)")
            }
        }
        return downloader.destination.appendingPathComponent(url.lastPathComponent)
        #else
        throw LocalLLMCommandError.invalidModel("Downloading models is not supported on this platform.")
        #endif
    }
}

// Benchmark data structures
struct BenchmarkMetrics: Codable {
    let firstTokenLatency: TimeInterval
    let promptDecodingTime: TimeInterval
    let tokensPerSecond: Double
    let totalTokens: Int
    let totalTime: TimeInterval
}

struct BenchmarkResult: Codable {
    let name: String
    let metrics: [BenchmarkMetrics]
    let summary: Summary
    let timestamp: Date

    struct Summary: Codable {
        let avgTokensPerSecond: Double
        let avgFirstTokenLatency: Double
        let minFirstTokenLatency: Double
        let maxFirstTokenLatency: Double
        let avgPromptDecodingTime: Double
        let minPromptDecodingTime: Double
        let maxPromptDecodingTime: Double
        let avgTotalTime: Double
        let minTotalTime: Double
        let maxTotalTime: Double
    }
}

