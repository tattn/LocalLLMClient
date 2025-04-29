// swift-tools-version: 6.1

import PackageDescription

let llamaVersion = "b5215"

let package = Package(
    name: "LocalLLMClient",
    platforms: [.iOS(.v18), .macOS(.v15), .watchOS(.v11), .tvOS(.v18), .visionOS(.v2)],
    products: [
        .library(
            name: "LocalLLMClient",
            targets: ["LocalLLMClient"])
    ],
    targets: [
        .target(
            name: "LocalLLMClient",
            dependencies: [
                "LlamaSwift"
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
            // swift package compute-checksum *.xcframework.zip
            checksum: "876d7bd423f508c1c3718e7b118047112e3a842175c6991f39773b2a3abcacd2"
        ),

        .target(name: "LLMCommon"),
    ]
)
