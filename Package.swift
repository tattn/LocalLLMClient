// swift-tools-version: 6.1

import PackageDescription

let llamaVersion = "b5242"

let package = Package(
    name: "LocalLLMClient",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(
            name: "LocalLLMClient",
            targets: ["LocalLLMClient"]),
        .library(
            name: "LlamaClient",
            targets: ["LlamaClient"]),
        .executable(
            name: "localllm",
            targets: ["LocalLLMCLI"]),

        .library(
            name: "MLXClient",
            targets: ["MLXClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", branch: "main"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.4.0"))
    ],
    targets: [
        .target(
            name: "LocalLLMClient"
        ),
        .executableTarget(
            name: "LocalLLMCLI",
            dependencies: [
                "LlamaClient",
                "MLXClient",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "LocalLLMClientTests",
            dependencies: ["LlamaClient"]
        ),

        .target(
            name: "LlamaClient",
            dependencies: [
                "LocalLLMClient",
                "LlamaClientExperimentalC",
                "LlamaFramework",
            ],
        ),
        .binaryTarget(
            name: "LlamaFramework",
            url:
                "https://github.com/ggml-org/llama.cpp/releases/download/\(llamaVersion)/llama-\(llamaVersion)-xcframework.zip",
            checksum: "482aa58c47c8dba464d589c6f7986d4035c403dad18696597f918ecb95cb3e19"
        ),

        .target(
            name: "LlamaClientExperimentalC",
            dependencies: ["LlamaFramework"],
            exclude: ["exclude"],
            cSettings: [
                .unsafeFlags(["-w"])
            ],
        ),

        .target(
            name: "MLXClient",
            dependencies: [
                "LocalLLMClient",
//                .product(name: "MLX", package: "mlx-swift-examples"),
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
            ],
        ),
    ]
)
