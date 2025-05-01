// swift-tools-version: 6.1

import PackageDescription

let llamaVersion = "b5242"

let package = Package(
    name: "LocalLLMClient",
    platforms: [.iOS(.v18), .macOS(.v15), .tvOS(.v18), .visionOS(.v2)],
    products: [
        .library(
            name: "LocalLLMClient",
            targets: ["LocalLLMClient"]),
        .executable(
            name: "localllm",
            targets: ["LocalLLMCLI"]),
        .library(
            name: "LocalLLMClientExperimental",
            targets: ["LlamaSwiftExperimental"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "LocalLLMClient",
            dependencies: [
                "LlamaSwift"
            ]
        ),
        .executableTarget(
            name: "LocalLLMCLI",
            dependencies: [
                "LocalLLMClient",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "LocalLLMClientTests",
            dependencies: ["LocalLLMClient"]
        ),

        .target(
            name: "LlamaSwift",
            dependencies: [
                "LLMCommon",
                "LlamaFramework",
            ],
        ),
        .binaryTarget(
            name: "LlamaFramework",
            url:
                "https://github.com/ggml-org/llama.cpp/releases/download/\(llamaVersion)/llama-\(llamaVersion)-xcframework.zip",
            checksum: "482aa58c47c8dba464d589c6f7986d4035c403dad18696597f918ecb95cb3e19"
        ),

        .target(name: "LLMCommon"),

        .target(name: "LlamaSwiftExperimental", dependencies: ["LlamaSwiftExperimentalC", "LlamaSwift"]),
        .target(name: "LlamaSwiftExperimentalC", dependencies: ["LlamaFramework"]),
    ]
)
