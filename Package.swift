// swift-tools-version: 6.1

import PackageDescription

let llamaVersion = "b5219"

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
            checksum: "7f24f4bf8de0013d574855598b5e86d67f0d250ee86d0281848062f994398715"
        ),

        .target(name: "LLMCommon"),
    ]
)
