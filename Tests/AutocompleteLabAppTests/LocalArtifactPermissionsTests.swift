import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

/// End-to-end proof that the live diagnostic/capture writers produce owner-only artifacts
/// (docs/security/threat-model.md F2). Permission logic is unit-tested in
/// `SecureLocalStorageTests`; these tests prove the writers actually route through it.
@Suite("Local artifact permissions")
struct LocalArtifactPermissionsTests {
    private func makeTempDirectoryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("steadytype-artifact-perms-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func posixMode(of url: URL) throws -> Int16 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let number = try #require(attributes[.posixPermissions] as? NSNumber)
        return number.int16Value & 0o777
    }

    @Test("Raw trace log writes an owner-only file in an owner-only directory")
    func rawTraceLogIsOwnerOnly() throws {
        let root = makeTempDirectoryURL()
        let logURL = root.appendingPathComponent("traces.jsonl")
        let screenshotsURL = root.appendingPathComponent("screenshots", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let defaults = try #require(UserDefaults(suiteName: "steadytype-trace-\(UUID().uuidString)"))
        let log = RawAutocompleteTraceLog(
            logURL: logURL,
            screenshotsURL: screenshotsURL,
            userDefaults: defaults,
            environment: [:]
        )

        log.recordAcceptance(
            action: "accepted",
            appBundleIdentifier: "com.apple.TextEdit",
            acceptedText: "hello",
            remainingVisibleText: nil
        )
        // recentEvents drains the writer's serial queue, so the async write has completed.
        _ = log.recentEvents(limit: 1)

        #expect(try posixMode(of: logURL) == 0o600)
        #expect(try posixMode(of: root) == 0o700)
    }

}
