// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Tilde",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(
            name: "Tilde",
            targets: ["AutocompleteLabApp"]
        ),
        .executable(
            name: "InlineGhostIME",
            targets: ["InlineGhostIME"]
        ),
        .executable(
            name: "TildeLab",
            targets: ["TildeLab"]
        ),
        .executable(
            name: "tilde-lab-runner",
            targets: ["TildeLabRunner"]
        )
    ],
    targets: [
        .target(
            name: "AutocompleteLabCore"
        ),
        .executableTarget(
            name: "InlineGhostIME",
            dependencies: ["AutocompleteLabCore"],
            exclude: ["Info.plist"],
            // IMKit's un-annotated types fight Swift 6 strict concurrency; the IME
            // stays in Swift 5 mode until the controller is modernized.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "AutocompleteLabApp",
            dependencies: ["AutocompleteLabCore"]
        ),
        .target(
            name: "TildeLabKit",
            dependencies: ["AutocompleteLabCore"],
            resources: [.process("Fixtures")]
        ),
        .executableTarget(
            name: "TildeLab",
            dependencies: ["TildeLabKit"]
        ),
        .executableTarget(
            name: "TildeLabRunner",
            dependencies: ["TildeLabKit"]
        ),
        .testTarget(
            name: "AutocompleteLabCoreTests",
            dependencies: ["AutocompleteLabCore"]
        ),
        .testTarget(
            name: "AutocompleteLabAppTests",
            dependencies: ["AutocompleteLabApp", "InlineGhostIME"]
        ),
        .testTarget(
            name: "TildeLabKitTests",
            dependencies: ["TildeLabKit", "AutocompleteLabCore"]
        )
    ]
)
