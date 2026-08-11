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
        .testTarget(
            name: "AutocompleteLabCoreTests",
            dependencies: ["AutocompleteLabCore"]
        ),
        .testTarget(
            name: "AutocompleteLabAppTests",
            dependencies: ["AutocompleteLabApp", "InlineGhostIME"]
        )
    ]
)
