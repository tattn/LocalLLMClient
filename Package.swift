// swift-tools-version: 6.0

import PackageDescription

let llamaVersion = "b5465"

let package = Package(
    name: "LocalLLMClient",
    platforms: [.iOS(.v16), .macOS(.v14)],
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
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.4.0")),
        .package(url: "https://github.com/huggingface/swift-transformers", .upToNextMinor(from: "0.1.20")),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.0")
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
            ],
            linkerSettings: [
                .unsafeFlags(["-rpath", "@executable_path"])
            ]
        ),

        .target(
            name: "LocalLLMClientLlama",
            dependencies: [
                "LocalLLMClient",
                "LocalLLMClientLlamaC",
                .product(name: "Transformers", package: "swift-transformers"),
            ],
            resources: [.process("Resources")],
            swiftSettings: Context.environment["BUILD_DOCC"] == nil ? [] : [
                .define("BUILD_DOCC")
            ]
        ),
        .binaryTarget(
            name: "LocalLLMClientLlamaFramework",
            url:
                "https://github.com/ggml-org/llama.cpp/releases/download/\(llamaVersion)/llama-\(llamaVersion)-xcframework.zip",
            checksum: "f246f3833b1cff61384c221b826551c7c9b27954f3588ac3034cde01b452f22e"
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
    ],
    cxxLanguageStandard: .cxx20
)
