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
            name: "InlineGhostIME",
            targets: ["InlineGhostIME"]
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
            name: "AutocompleteLabCore"
        ),
        .executableTarget(
            name: "InlineGhostIME",
            exclude: ["Info.plist", "README.md"],
            // IMKit's un-annotated types fight Swift 6 strict concurrency; the IME
            // stays in Swift 5 mode until the controller is modernized.
            swiftSettings: [.swiftLanguageMode(.v5)]
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
            ]
        ),
        .testTarget(
            name: "AutocompleteLabCoreTests",
            dependencies: ["AutocompleteLabCore"]
        ),
        .testTarget(
            name: "AutocompleteLabAppTests",
            dependencies: ["AutocompleteLabApp"]
        )
    ]
)
