// swift-tools-version: 6.1

import PackageDescription
import CompilerPluginSupport

let llamaVersion = "b6628"

// MARK: - Package Dependencies

var packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.4.0")),
    .package(url: "https://github.com/huggingface/swift-jinja", .upToNextMinor(from: "2.0.0")),
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.0")
]

#if os(iOS) || os(macOS)
packageDependencies.append(contentsOf: [
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
    .library(name: "LocalLLMClientLlama", targets: ["LocalLLMClientLlama"]),
    .library(name: "LocalLLMClientMLX", targets: ["LocalLLMClientMLX"]),
    .library(name: "LocalLLMClientFoundationModels", targets: ["LocalLLMClientFoundationModels"]),
])
#elseif os(Linux)
packageProducts.append(contentsOf: [
    .executable(name: "localllm", targets: ["LocalLLMCLI"]),
    .library(name: "LocalLLMClientLlama", targets: ["LocalLLMClientLlama"]),
])
#endif

// MARK: - Package Targets

var packageTargets: [Target] = [
    .target(
        name: "LocalLLMClient",
        dependencies: [
            "LocalLLMClientCore",
            "LocalLLMClientMacros"
        ]
    ),
    .testTarget(
        name: "LocalLLMClientTests",
        dependencies: ["LocalLLMClient", "LocalLLMClientTestUtilities"]
    ),
    
    .target(
        name: "LocalLLMClientCore", 
        dependencies: [
            "LocalLLMClientUtility",
            .product(name: "Jinja", package: "swift-jinja")
        ]
    ),

    .target(name: "LocalLLMClientUtility"),
    .target(
        name: "LocalLLMClientTestUtilities",
        dependencies: ["LocalLLMClientCore", "LocalLLMClientMacros"]
    ),
    
    .macro(
        name: "LocalLLMClientMacrosPlugin",
        dependencies: [
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
        ]
    ),
    .target(
        name: "LocalLLMClientMacros",
        dependencies: ["LocalLLMClientMacrosPlugin", "LocalLLMClientCore"]
    ),
    .testTarget(
        name: "LocalLLMClientMacrosTests",
        dependencies: [
            "LocalLLMClientCore",
            "LocalLLMClientMacros",
            "LocalLLMClientMacrosPlugin",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
        ]
    )
]

#if os(iOS) || os(macOS)
packageTargets.append(contentsOf: [
    .executableTarget(
        name: "LocalLLMCLI",
        dependencies: [
            "LocalLLMClientLlama",
            "LocalLLMClientMLX",
            "LocalLLMClientFoundationModels",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ],
        swiftSettings: [
            .interoperabilityMode(.Cxx)
        ],
        linkerSettings: [
            .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path"])
        ]
    ),

    .target(
        name: "LocalLLMClientLlama",
        dependencies: [
            "LocalLLMClientCore",
            "LocalLLMClientLlamaC"
        ],
        resources: [.process("Resources")],
        swiftSettings: (Context.environment["BUILD_DOCC"] == nil ? [] : [
            .define("BUILD_DOCC")
        ]) + [
            .interoperabilityMode(.Cxx)
        ]
    ),
    .testTarget(
        name: "LocalLLMClientLlamaTests",
        dependencies: ["LocalLLMClientLlama", "LocalLLMClientTestUtilities"],
        swiftSettings: [
            .interoperabilityMode(.Cxx)
        ]
    ),

    .target(
        name: "LocalLLMClientMLX",
        dependencies: [
            "LocalLLMClientCore",
            .product(name: "MLXLLM", package: "mlx-swift-examples"),
            .product(name: "MLXVLM", package: "mlx-swift-examples"),
        ],
    ),
    .testTarget(
        name: "LocalLLMClientMLXTests",
        dependencies: ["LocalLLMClientMLX", "LocalLLMClientTestUtilities"]
    ),
    .target(
        name: "LocalLLMClientFoundationModels",
        dependencies: ["LocalLLMClient"]
    ),
    .testTarget(
        name: "LocalLLMClientFoundationModelsTests",
        dependencies: ["LocalLLMClientFoundationModels", "LocalLLMClientTestUtilities"]
    ),

    .binaryTarget(
        name: "LocalLLMClientLlamaFramework",
        url:
            "https://github.com/ggml-org/llama.cpp/releases/download/\(llamaVersion)/llama-\(llamaVersion)-xcframework.zip",
        checksum: "b25aad9f424ecb7d589d843deabd0ebc0f0d6f9ea126f7d31bb1ac5204543fa9"
    ),
    .target(
        name: "LocalLLMClientLlamaC",
        dependencies: ["LocalLLMClientLlamaFramework"],
        exclude: ["exclude"],
        cSettings: [
            .unsafeFlags(["-w"]),
            .headerSearchPath(".")
        ],
        cxxSettings: [
            .headerSearchPath(".")
        ],
        swiftSettings: [
            .interoperabilityMode(.Cxx)
        ]
    ),

    .testTarget(
        name: "LocalLLMClientUtilityTests",
        dependencies: [
            "LocalLLMClientUtility",
            .product(name: "MLXLMCommon", package: "mlx-swift-examples")
        ]
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
        swiftSettings: [
            .interoperabilityMode(.Cxx)
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
            "LocalLLMClientCore",
            "LocalLLMClientLlamaC"
        ],
        resources: [.process("Resources")],
        swiftSettings: [
            .interoperabilityMode(.Cxx)
        ]
    ),
    .testTarget(
        name: "LocalLLMClientLlamaTests",
        dependencies: ["LocalLLMClientLlama", "LocalLLMClientTestUtilities"],
        swiftSettings: [
            .interoperabilityMode(.Cxx)
        ],
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
            .unsafeFlags(["-w"]),
            .headerSearchPath(".")
        ],
        cxxSettings: [
            .headerSearchPath(".")
        ],
        swiftSettings: [
            .interoperabilityMode(.Cxx)
        ],
        linkerSettings: [
            .unsafeFlags([
                 "-lggml-base", "-lggml", "-lllama", "-lmtmd"
            ])
        ]
    ),

    .testTarget(
        name: "LocalLLMClientUtilityTests",
        dependencies: ["LocalLLMClientUtility"]
    )
])
#endif

// MARK: - Package Definition

let package = Package(
    name: "LocalLLMClient",
    platforms: [.iOS(.v16), .macOS(.v14)],
    products: packageProducts,
    dependencies: packageDependencies,
    targets: packageTargets,
    cxxLanguageStandard: .cxx17
)
