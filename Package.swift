// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SteadyType",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "AutocompleteLabCore",
            targets: ["AutocompleteLabCore"]
        ),
        .executable(
            name: "SteadyType",
            targets: ["AutocompleteLabApp"]
        ),
        .executable(
            name: "AutocompleteTraceReplay",
            targets: ["AutocompleteTraceReplay"]
        ),
        .executable(
            name: "SteadyTypeTextEventHelper",
            targets: ["SteadyTypeTextEventHelper"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift", .upToNextMajor(from: "0.31.3")),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", .upToNextMajor(from: "3.31.3")),
        .package(url: "https://github.com/huggingface/swift-huggingface.git", .upToNextMajor(from: "0.9.0")),
        .package(url: "https://github.com/huggingface/swift-transformers.git", .upToNextMajor(from: "1.3.0"))
    ],
    targets: [
        .target(
            name: "AutocompleteLabCore",
            exclude: [
                "AGENTS.md",
                "CLAUDE.md",
                "Compatibility/AGENTS.md",
                "Compatibility/CLAUDE.md",
                "Configuration/AGENTS.md",
                "Configuration/CLAUDE.md",
                "Engine/AGENTS.md",
                "Engine/CLAUDE.md",
                "Experiments/AGENTS.md",
                "Experiments/CLAUDE.md",
                "Geometry/AGENTS.md",
                "Geometry/CLAUDE.md",
                "Runtime/AGENTS.md",
                "Runtime/CLAUDE.md",
                "Session/AGENTS.md",
                "Session/CLAUDE.md",
                "Suggestions/AGENTS.md",
                "Suggestions/CLAUDE.md",
                "Text/AGENTS.md",
                "Text/CLAUDE.md",
                "Tracing/AGENTS.md",
                "Tracing/CLAUDE.md"
            ]
        ),
        .executableTarget(
            name: "AutocompleteLabApp",
            dependencies: [
                "AutocompleteLabCore",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXVLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "Hub", package: "swift-transformers"),
                .product(name: "Tokenizers", package: "swift-transformers")
            ],
            exclude: [
                "AGENTS.md",
                "CLAUDE.md",
                "App/AGENTS.md",
                "App/CLAUDE.md",
                "Mac/AGENTS.md",
                "Mac/CLAUDE.md",
                "Runtime/AGENTS.md",
                "Runtime/CLAUDE.md",
                "UI/AGENTS.md",
                "UI/CLAUDE.md"
            ]
        ),
        .executableTarget(
            name: "AutocompleteTraceReplay",
            dependencies: ["AutocompleteLabCore"],
            exclude: [
                "AGENTS.md",
                "CLAUDE.md"
            ]
        ),
        .executableTarget(
            name: "SteadyTypeTextEventHelper",
            exclude: [
                "AGENTS.md",
                "CLAUDE.md"
            ]
        ),
        .testTarget(
            name: "AutocompleteLabCoreTests",
            dependencies: ["AutocompleteLabCore"],
            exclude: [
                "AGENTS.md",
                "CLAUDE.md"
            ]
        ),
        .testTarget(
            name: "AutocompleteLabAppTests",
            dependencies: ["AutocompleteLabApp"],
            exclude: [
                "AGENTS.md",
                "CLAUDE.md"
            ]
        )
    ]
)
