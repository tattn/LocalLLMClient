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
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "LocalLLMClient"
        ),
        .executableTarget(
            name: "LocalLLMCLI",
            dependencies: [
                "LlamaSwift",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "LocalLLMClientTests",
            dependencies: ["LlamaSwift"]
        ),

        .target(
            name: "LlamaSwift",
            dependencies: [
                "LocalLLMClient",
                "LlamaSwiftExperimentalC",
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
            name: "LlamaSwiftExperimentalC",
            dependencies: ["LlamaFramework"],
            exclude: ["exclude"],
            cSettings: [
                .unsafeFlags(["-w"])
            ],
        ),
    ]
)
