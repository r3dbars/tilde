import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Local model installer")
struct LocalModelInstallerTests {
    @Test("Install progress formats unknown and bounded percentages")
    func installProgressFormatsPercentages() {
        #expect(
            LocalModelInstallProgress(
                completedUnitCount: 0,
                totalUnitCount: 0
            ).percentageText == "starting"
        )
        #expect(
            LocalModelInstallProgress(
                completedUnitCount: 50,
                totalUnitCount: 100
            ).percentageText == "50%"
        )
        #expect(
            LocalModelInstallProgress(
                completedUnitCount: 150,
                totalUnitCount: 100
            ).percentageText == "100%"
        )
    }

    @Test("Installer fails locally when manifest has no app-owned source")
    func installerFailsLocallyWhenSourceIsMissing() async {
        let installer = LocalModelInstaller()
        let destination = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        await #expect(throws: LocalModelInstallerError.missingSource(.qwen35NineB)) {
            try await installer.install(
                manifest: .qwen35NineBMLX,
                to: destination
            )
        }
    }
}
