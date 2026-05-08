import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Compatibility learning privacy")
struct CompatibilityLearningStorePrivacyTests {
    @Test("Per-app screenshot tracing expires and can be disabled")
    func perAppScreenshotTracingExpiresAndCanBeDisabled() {
        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("CompatibilityLearningStorePrivacyTests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: temporaryFolder)
        }

        let clock = StoreTestClock(Date(timeIntervalSince1970: 1_000))
        let store = CompatibilityLearningStore(
            fileURL: temporaryFolder.appendingPathComponent("compatibility-learning.json"),
            screenshotTracingDuration: 60,
            now: { clock.current }
        )
        let bundleIdentifier = "com.example.editor"

        store.setScreenshotTracing(true, for: bundleIdentifier)

        let activeProfile = store.profile(for: bundleIdentifier)
        #expect(activeProfile?.screenshotTracingEnabled == true)
        #expect(activeProfile?.screenshotTracingExpiresAt != nil)
        #expect(
            store.engine()
                .adjustment(for: bundleIdentifier, profileRenderMode: .inlineAdjacent)
                .shouldCaptureScreenshot
        )

        clock.current = Date(timeIntervalSince1970: 1_061)

        #expect(store.profile(for: bundleIdentifier)?.screenshotTracingEnabled == false)
        #expect(
            !store.engine()
                .adjustment(for: bundleIdentifier, profileRenderMode: .inlineAdjacent)
                .shouldCaptureScreenshot
        )

        store.setScreenshotTracing(true, for: bundleIdentifier)
        store.disableScreenshotTracing()

        #expect(store.profile(for: bundleIdentifier)?.screenshotTracingEnabled == false)
        #expect(store.profile(for: bundleIdentifier)?.screenshotTracingExpiresAt == nil)
    }

    @Test("Legacy per-app screenshot tracing without expiry reads disabled")
    func legacyPerAppScreenshotTracingWithoutExpiryReadsDisabled() throws {
        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("CompatibilityLearningStorePrivacyTests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: temporaryFolder)
        }

        let fileURL = temporaryFolder.appendingPathComponent("compatibility-learning.json")
        try FileManager.default.createDirectory(at: temporaryFolder, withIntermediateDirectories: true)
        let bundleIdentifier = "com.example.legacy"
        let profile = CompatibilityLearningProfile(
            bundleIdentifier: bundleIdentifier,
            screenshotTracingEnabled: true
        )
        try JSONEncoder().encode([bundleIdentifier: profile]).write(to: fileURL)

        let store = CompatibilityLearningStore(fileURL: fileURL)

        #expect(store.profile(for: bundleIdentifier)?.screenshotTracingEnabled == false)
    }
}

private final class StoreTestClock {
    var current: Date

    init(_ current: Date) {
        self.current = current
    }
}
