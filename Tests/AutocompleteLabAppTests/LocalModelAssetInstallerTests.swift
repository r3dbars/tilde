import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Local model asset installer")
struct LocalModelAssetInstallerTests {
    @Test("Progress copy is short and percent based")
    func progressCopyIsShortAndPercentBased() {
        let progress = LocalModelInstallProgress(
            phase: .downloading,
            completedUnitCount: 1,
            totalUnitCount: 4
        )

        #expect(progress.fractionCompleted == 0.25)
        #expect(progress.userFacingText == "Model install: 25% downloaded")
        #expect(LocalModelInstallProgress(phase: .preparing).userFacingText == "Model install: preparing download")
        #expect(LocalModelInstallProgress(phase: .validating).userFacingText == "Model install: validating files")
        #expect(LocalModelInstallProgress(phase: .installed).userFacingText == "Model install: ready to warm")
    }

    @Test("Installer fails before network when no source exists")
    func installerFailsBeforeNetworkWhenNoSourceExists() async {
        let installer = LocalModelAssetInstaller(
            manifest: .qwen35NineBMLX,
            destinationURL: URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("autocomplete-installer-test-\(UUID().uuidString)")
        )

        await #expect(throws: LocalModelAssetInstallerError.self) {
            try await installer.install()
        }
    }

    @Test("Installer errors use plain recovery copy")
    func installerErrorsUsePlainRecoveryCopy() {
        #expect(
            LocalModelAssetInstallerError.missingSource(model: "qwen35-9b").errorDescription
                == "This model cannot be installed in the app yet: qwen35-9b. Open the model folder or choose the default model."
        )
        #expect(
            LocalModelAssetInstallerError.invalidRepository("bad repo").errorDescription
                == "The model download address is invalid: bad repo."
        )
        #expect(
            LocalModelAssetInstallerError.insufficientDiskSpace(
                requiredBytes: 5_000_000_000,
                availableBytes: 2_000_000_000
            ).errorDescription
                == "Not enough free space for the local model. Free about 3 GB and try again."
        )
        #expect(
            LocalModelAssetInstallerError.invalidAfterInstall("missing config.json").errorDescription
                == "The downloaded model files still look incomplete: missing config.json."
        )
    }

    @Test("Preflight blocks installs before network when disk space is too low")
    func preflightBlocksInstallsBeforeNetworkWhenDiskSpaceIsTooLow() {
        let policy = LocalModelInstallPreflightPolicy(overheadMultiplier: 1.25)

        #expect(throws: LocalModelAssetInstallerError.insufficientDiskSpace(
            requiredBytes: 5_000_000_000,
            availableBytes: 4_999_999_999
        )) {
            try policy.validate(
                availableBytes: 4_999_999_999,
                expectedMinimumBytes: 4_000_000_000
            )
        }
    }

    @Test("Preflight allows unknown or sufficient disk space")
    func preflightAllowsUnknownOrSufficientDiskSpace() throws {
        let policy = LocalModelInstallPreflightPolicy(overheadMultiplier: 1.25)

        try policy.validate(availableBytes: nil, expectedMinimumBytes: 4_000_000_000)
        try policy.validate(availableBytes: 5_000_000_000, expectedMinimumBytes: 4_000_000_000)
    }
}
