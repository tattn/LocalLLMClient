// swift-tools-version: 6.1

import PackageDescription

let llamaVersion = "b5278"

let package = Package(
    name: "LocalLLMClient",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(
            name: "LocalLLMClient",
            targets: ["LocalLLMClient"]),

        .library(
            name: "LocalLLMClientLlama",
            targets: ["LocalLLMClientLlama"]),

        .library(
            name: "LocalLLMClientMLX",
            targets: ["LocalLLMClientMLX"]),

        .library(
            name: "LocalLLMClientUtility",
            targets: ["LocalLLMClientUtility"]),

        .executable(
            name: "localllm",
            targets: ["LocalLLMCLI"]),
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
                "LocalLLMClientLlama",
                "LocalLLMClientMLX",
                "LocalLLMClientUtility",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        .target(
            name: "LocalLLMClientLlama",
            dependencies: [
                "LocalLLMClient",
                "LocalLLMClientLlamaC",
                "LocalLLMClientLlamaFramework",
            ],
        ),
        .binaryTarget(
            name: "LocalLLMClientLlamaFramework",
            url:
                "https://github.com/ggml-org/llama.cpp/releases/download/\(llamaVersion)/llama-\(llamaVersion)-xcframework.zip",
            checksum: "9d81d4f5340152bdb4888d74d3b0a1202650e29f13ce40bb598d0a5cb7ec1f68"
        ),
        .target(
            name: "LocalLLMClientLlamaC",
            dependencies: ["LocalLLMClientLlamaFramework"],
            exclude: ["exclude"],
            cSettings: [
                .unsafeFlags(["-w"])
            ],
        ),
        .testTarget(
            name: "LocalLLMClientLlamaTests",
            dependencies: ["LocalLLMClientLlama", "LocalLLMClientUtility"]
        ),

        .target(
            name: "LocalLLMClientMLX",
            dependencies: [
                "LocalLLMClient",
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                .product(name: "MLXVLM", package: "mlx-swift-examples"),
            ],
        ),
        .testTarget(
            name: "LocalLLMClientMLXTests",
            dependencies: ["LocalLLMClientMLX", "LocalLLMClientUtility"]
        ),

        .target(
            name: "LocalLLMClientUtility",
            dependencies: [
                .product(name: "MLXLMCommon", package: "mlx-swift-examples"),
            ],
        ),
    ]
)
