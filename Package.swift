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
    targets: [
        .target(
            name: "AutocompleteLabCore",
            exclude: [
                "AGENTS.md",
                "Compatibility/AGENTS.md",
                "Configuration/AGENTS.md",
                "Engine/AGENTS.md",
                "Geometry/AGENTS.md",
                "Runtime/AGENTS.md",
                "Session/AGENTS.md",
                "Suggestions/AGENTS.md",
                "Text/AGENTS.md"
            ]
        ),
        .executableTarget(
            name: "AutocompleteLabApp",
            dependencies: ["AutocompleteLabCore"],
            exclude: [
                "AGENTS.md",
                "App/AGENTS.md",
                "Mac/AGENTS.md",
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
