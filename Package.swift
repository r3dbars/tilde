// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Tilde",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        // Tilde: the shipped product.
        .executable(
            name: "Tilde",
            targets: ["TildeApp"]
        ),
        .executable(
            name: "InlineGhostIME",
            targets: ["InlineGhostIME"]
        ),
        // Tilde Lab: development-only experiment tools. None of these targets
        // are dependencies of TildeApp or InlineGhostIME.
        .executable(
            name: "TildeLab",
            targets: ["TildeLab"]
        ),
        .executable(
            name: "tilde-lab-runner",
            targets: ["TildeLabRunner"]
        ),
        .executable(
            name: "tilde-lab",
            targets: ["TildeLabCLI"]
        )
    ],
    targets: [
        // Shared production policy. Tilde Lab may test it, but production
        // targets never depend on a Tilde Lab target.
        .target(
            name: "TildeCore"
        ),
        // Tilde Lab's SQLite adapter is development-only.
        .systemLibrary(name: "CSQLite"),
        .executableTarget(
            name: "InlineGhostIME",
            dependencies: ["TildeCore"],
            exclude: ["Info.plist"],
            // IMKit's un-annotated types fight Swift 6 strict concurrency; the IME
            // stays in Swift 5 mode until the controller is modernized.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "TildeApp",
            dependencies: ["TildeCore"]
        ),
        .target(
            name: "TildeLabKit",
            dependencies: ["TildeCore", "CSQLite"],
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
        .executableTarget(
            name: "TildeLabCLI",
            dependencies: ["TildeLabKit"]
        ),
        .testTarget(
            name: "TildeCoreTests",
            dependencies: ["TildeCore"]
        ),
        .testTarget(
            name: "TildeAppTests",
            dependencies: ["TildeApp", "InlineGhostIME"]
        ),
        .testTarget(
            name: "TildeLabKitTests",
            dependencies: ["TildeLabKit", "TildeCore"]
        )
    ]
)
