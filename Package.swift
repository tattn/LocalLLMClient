// swift-tools-version: 6.0

import PackageDescription

let llamaVersion = "b5510"

// MARK: - Package Dependencies

var packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.4.0")),
    .package(url: "https://github.com/johnmai-dev/Jinja", .upToNextMinor(from: "1.1.0")),
]

#if os(iOS) || os(macOS)
packageDependencies.append(contentsOf: [
    .package(url: "https://github.com/huggingface/swift-transformers", .upToNextMinor(from: "0.1.20")),
    .package(url: "https://github.com/ml-explore/mlx-swift-examples", branch: "main"),
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.0")
])
#endif

// MARK: - Package Products

var packageProducts: [Product] = [
    .library(name: "LocalLLMClient", targets: ["LocalLLMClient"])
]

#if os(iOS) || os(macOS)
packageProducts.append(contentsOf: [
    .executable(name: "localllm", targets: ["LocalLLMCLI"]),
    .library(name: "LocalLLMClientLlama", targets: ["LocalLLMClientLlama"]),
    .library(name: "LocalLLMClientMLX", targets: ["LocalLLMClientMLX"]),
    .library(name: "LocalLLMClientUtility", targets: ["LocalLLMClientUtility"])
])
#elseif os(Linux)
packageProducts.append(contentsOf: [
    .executable(name: "localllm", targets: ["LocalLLMCLI"]),
    .library(name: "LocalLLMClientLlama", targets: ["LocalLLMClientLlama"]),
])
#endif

// MARK: - Package Targets

var packageTargets: [Target] = [
    .target(name: "LocalLLMClient")
]

#if os(iOS) || os(macOS)
packageTargets.append(contentsOf: [
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
            .product(name: "Jinja", package: "Jinja")
        ],
        resources: [.process("Resources")],
        swiftSettings: Context.environment["BUILD_DOCC"] == nil ? [] : [
            .define("BUILD_DOCC")
        ]
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

    .binaryTarget(
        name: "LocalLLMClientLlamaFramework",
        url:
            "https://github.com/ggml-org/llama.cpp/releases/download/\(llamaVersion)/llama-\(llamaVersion)-xcframework.zip",
        checksum: "646b011454d2c3dd00d34931653a37f133ec60948ba3d5af03873ce32d5610e3"
    ),
    .target(
        name: "LocalLLMClientLlamaC",
        dependencies: ["LocalLLMClientLlamaFramework"],
        exclude: ["exclude"],
        cSettings: [
            .unsafeFlags(["-w"])
        ],
    ),

    .target(
        name: "LocalLLMClientUtility",
        dependencies: [
            .product(name: "MLXLMCommon", package: "mlx-swift-examples"),
        ],
    ),
    .testTarget(
        name: "LocalLLMClientUtilityTests",
        dependencies: ["LocalLLMClientUtility"]
    )
])
#elseif os(Linux)
packageTargets.append(contentsOf: [
    .executableTarget(
        name: "LocalLLMCLI",
        dependencies: [
            "LocalLLMClientLlama",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ],
        linkerSettings: [
            .unsafeFlags([
                Context.environment["LDFLAGS", default: ""],
            ])
        ]
    ),

    .target(
        name: "LocalLLMClientLlama",
        dependencies: [
            "LocalLLMClient",
            "LocalLLMClientLlamaC",
            .product(name: "Jinja", package: "Jinja")
        ],
        resources: [.process("Resources")]
    ),
    .testTarget(
        name: "LocalLLMClientLlamaTests",
        dependencies: ["LocalLLMClientLlama"],
        linkerSettings: [
            .unsafeFlags([
                Context.environment["LDFLAGS", default: ""],
            ])
        ]
    ),

    .target(
        name: "LocalLLMClientLlamaC",
        exclude: ["exclude"],
        cSettings: [
            .unsafeFlags(["-w"])
        ],
        linkerSettings: [
            .unsafeFlags([
                "-lggml-base", "-lggml-cpu", "-lggml-rpc", "-lggml", "-lllama", "-lmtmd_shared"
            ])
        ]
    ),
])
#endif

// MARK: - Package Definition

let package = Package(
    name: "LocalLLMClient",
    platforms: [.iOS(.v16), .macOS(.v14)],
    products: packageProducts,
    dependencies: packageDependencies,
    targets: packageTargets,
    cxxLanguageStandard: .cxx20
)
