// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TranscriptedAutocompleteLab",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "AutocompleteLabCore",
            targets: ["AutocompleteLabCore"]
        ),
        .executable(
            name: "AutocompleteLab",
            targets: ["AutocompleteLabApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", .upToNextMajor(from: "3.31.3")),
        .package(url: "https://github.com/huggingface/swift-transformers.git", .upToNextMajor(from: "1.3.0"))
    ],
    targets: [
        .target(
            name: "AutocompleteLabCore",
            exclude: [
                "AGENTS.md",
                "Configuration/AGENTS.md",
                "Engine/AGENTS.md",
                "Geometry/AGENTS.md",
                "Runtime/AGENTS.md",
                "Session/AGENTS.md",
                "Suggestions/AGENTS.md",
                "Text/AGENTS.md",
                "Tracing/AGENTS.md"
            ]
        ),
        .executableTarget(
            name: "AutocompleteLabApp",
            dependencies: [
                "AutocompleteLabCore",
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXVLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "Tokenizers", package: "swift-transformers")
            ],
            exclude: [
                "AGENTS.md",
                "App/AGENTS.md",
                "Mac/AGENTS.md",
                "Runtime/AGENTS.md",
                "UI/AGENTS.md"
            ]
        ),
        .testTarget(
            name: "AutocompleteLabCoreTests",
            dependencies: ["AutocompleteLabCore"],
            exclude: ["AGENTS.md"]
        )
    ]
)
