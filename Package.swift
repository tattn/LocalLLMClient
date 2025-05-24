// swift-tools-version: 6.0

import PackageDescription

let llamaVersion = "b5465"

// Define common dependencies
var packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.4.0")),
    .package(url: "https://github.com/huggingface/swift-transformers", .upToNextMinor(from: "0.1.20")),
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.0")
]

var localLLMClientMLXProductName: Target.Dependency? = nil
var localLLMClientMLXTarget: Target? = nil
var localLLMClientMLXTestsTarget: Target? = nil
var mlxLmCommonDependency: Target.Dependency? = nil

#if !os(Linux)
packageDependencies.append(.package(url: "https://github.com/ml-explore/mlx-swift-examples", branch: "main"))
localLLMClientMLXProductName = .target(name: "LocalLLMClientMLX")
mlxLmCommonDependency = .product(name: "MLXLMCommon", package: "mlx-swift-examples")

localLLMClientMLXTarget = .target(
    name: "LocalLLMClientMLX",
    dependencies: [
        "LocalLLMClient",
        .product(name: "MLXLLM", package: "mlx-swift-examples"),
        .product(name: "MLXVLM", package: "mlx-swift-examples"),
    ]
)

localLLMClientMLXTestsTarget = .testTarget(
    name: "LocalLLMClientMLXTests",
    dependencies: ["LocalLLMClientMLX", "LocalLLMClientUtility"]
)
#endif

var products: [Product] = [
    .library(
        name: "LocalLLMClient",
        targets: ["LocalLLMClient"]),
    .library(
        name: "LocalLLMClientLlama",
        targets: ["LocalLLMClientLlama"]),
    .library(
        name: "LocalLLMClientUtility",
        targets: ["LocalLLMClientUtility"]),
    .executable(
        name: "localllm",
        targets: ["LocalLLMCLI"]),
]

if let localLLMClientMLXProductName = localLLMClientMLXProductName {
    products.append(.library(name: "LocalLLMClientMLX", targets: ["LocalLLMClientMLX"]))
}


var targets: [Target] = [
    .target(
        name: "LocalLLMClient"
    ),
    .executableTarget(
        name: "LocalLLMCLI",
        dependencies: {
            var deps: [Target.Dependency] = [
                "LocalLLMClientLlama",
                "LocalLLMClientUtility",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
            if let mlxProduct = localLLMClientMLXProductName {
                deps.insert(mlxProduct, at: 1) // Insert after Llama, before Utility
            }
            return deps
        }(),
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
    .testTarget(
        name: "LocalLLMClientLlamaTests",
        dependencies: ["LocalLLMClientLlama", "LocalLLMClientUtility"]
    ),
    .testTarget(
        name: "LinuxCompatibilityTests",
        dependencies: ["LocalLLMClient"]
    ),
    .target(
        name: "LocalLLMClientUtility",
        dependencies: {
            var deps: [Target.Dependency] = []
            if let mlxCommonDep = mlxLmCommonDependency {
                deps.append(mlxCommonDep)
            }
            return deps
        }()
    ),
]

#if !os(Linux)
targets.append(
    .binaryTarget(
        name: "LocalLLMClientLlamaFramework",
        url:
            "https://github.com/ggml-org/llama.cpp/releases/download/\(llamaVersion)/llama-\(llamaVersion)-xcframework.zip",
        checksum: "f246f3833b1cff61384c221b826551c7c9b27954f3588ac3034cde01b452f22e"
    )
)
targets.append(
    .target(
        name: "LocalLLMClientLlamaC",
        dependencies: ["LocalLLMClientLlamaFramework"],
        exclude: ["exclude"],
        cSettings: [
            .unsafeFlags(["-w"])
        ]
    )
)
#else
targets.append(
    .target(
        name: "LocalLLMClientLlamaC",
        // No dependency on the framework for Linux
        dependencies: [],
        // Assuming sources are in Sources/LocalLLMClientLlamaC/exclude
        // and we want to compile them all for Linux.
        // This means removing "exclude" from the exclude list.
        // Or, more explicitly, defining sources.
        // For now, let's try to include all sources by not excluding 'exclude'.
        // We might need to list them explicitly if there are non-C/CPP files.
        sources: ["common/common.cpp", "ggml/ggml.c", "ggml/ggml-alloc.c", "ggml/ggml-backend.c", "ggml/ggml-mpi.c", "ggml/ggml-quants.c", "llama.cpp"],
        publicHeadersPath: "common", // Assuming common headers are here
        cSettings: [
            .unsafeFlags(["-w"]), // Keep existing warning suppression
            .define("GGML_USE_PTHREAD", .when(platforms: [.linux])),
            .define("GGML_USE_LLAMAFILE", .when(platforms: [.linux])), // Example, if needed
            // We might need to add include paths if headers are not found
            // For example, if llama.h is at the root of 'exclude'
            .headerSearchPath("."), // Current directory within target
            .headerSearchPath("ggml"), // For ggml headers
            .headerSearchPath("common"), // For common headers
        ],
        cxxSettings: [
            // Add any C++ specific settings if needed
            .define("GGML_USE_PTHREAD", .when(platforms: [.linux])),
        ],
        linkerSettings: [
            .linkedLibrary("pthread", .when(platforms: [.linux])), // Link pthread on Linux
            .linkedLibrary("dl", .when(platforms: [.linux])), // Link dl on Linux
        ]
    )
)
#endif

if let mlxTarget = localLLMClientMLXTarget {
    targets.append(mlxTarget)
}
if let mlxTestsTarget = localLLMClientMLXTestsTarget {
    targets.append(mlxTestsTarget)
}


let package = Package(
    name: "LocalLLMClient",
    platforms: [.iOS(.v16), .macOS(.v14), .linux(.v5_10)],
    products: products,
    dependencies: packageDependencies,
    targets: targets,
    cxxLanguageStandard: .cxx20
)
