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

    @Test("Manual render mode override persists and clears")
    func manualRenderModeOverridePersistsAndClears() {
        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("CompatibilityLearningStorePrivacyTests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: temporaryFolder)
        }

        let store = CompatibilityLearningStore(
            fileURL: temporaryFolder.appendingPathComponent("compatibility-learning.json")
        )
        let bundleIdentifier = "com.example.editor"

        store.setRenderModeOverride(.floatingMirror, for: bundleIdentifier)

        #expect(store.profile(for: bundleIdentifier)?.renderModeOverride == .floatingMirror)
        #expect(
            store.engine()
                .adjustment(for: bundleIdentifier, profileRenderMode: .inlineAdjacent)
                .effectiveRenderMode == .floatingMirror
        )

        store.setRenderModeOverride(nil, for: bundleIdentifier)

        #expect(store.profile(for: bundleIdentifier)?.renderModeOverride == nil)
        #expect(
            store.engine()
                .adjustment(for: bundleIdentifier, profileRenderMode: .inlineAdjacent)
                .effectiveRenderMode == .inlineAdjacent
        )
    }

    @Test("Screenshot visual corrections persist scoped trust context")
    func screenshotVisualCorrectionsPersistScopedTrustContext() {
        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("CompatibilityLearningStorePrivacyTests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: temporaryFolder)
        }

        let store = CompatibilityLearningStore(
            fileURL: temporaryFolder.appendingPathComponent("compatibility-learning.json")
        )
        let bundleIdentifier = "com.example.editor"
        let context = CompatibilityLearningVisualTrustContext(
            appVersion: "2.0#200",
            screenFingerprint: "screen-a",
            fieldShapeFingerprint: "field-a"
        )

        store.updateOffset(
            x: 4,
            y: -3,
            for: bundleIdentifier,
            reason: "screenshot-visual-correction",
            visualTrustContext: context,
            confidence: 0.86
        )

        let profile = store.profile(for: bundleIdentifier)
        #expect(profile?.visualAppVersion == "2.0#200")
        #expect(profile?.visualScreenFingerprint == "screen-a")
        #expect(profile?.visualFieldShapeFingerprint == "field-a")
        #expect(profile?.confidence == 0.86)

        let matchingAdjustment = store.engine()
            .adjustment(for: bundleIdentifier, profileRenderMode: .inlineAdjacent)
            .trustedVisualOffsetOnly(context: context)
        let movedFieldAdjustment = store.engine()
            .adjustment(for: bundleIdentifier, profileRenderMode: .inlineAdjacent)
            .trustedVisualOffsetOnly(context: CompatibilityLearningVisualTrustContext(
                appVersion: "2.0#200",
                screenFingerprint: "screen-a",
                fieldShapeFingerprint: "field-b"
            ))
        let rect = CGRect(x: 100, y: 200, width: 0, height: 20)

        #expect(matchingAdjustment.adjusted(rect) == CGRect(x: 104, y: 197, width: 0, height: 20))
        #expect(movedFieldAdjustment.adjusted(rect) == rect)
    }

    @Test("Generic observations preserve trusted visual correction reason")
    func genericObservationsPreserveTrustedVisualCorrectionReason() {
        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("CompatibilityLearningStorePrivacyTests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: temporaryFolder)
        }

        let store = CompatibilityLearningStore(
            fileURL: temporaryFolder.appendingPathComponent("compatibility-learning.json")
        )
        let bundleIdentifier = "com.example.editor"
        let context = CompatibilityLearningVisualTrustContext(
            appVersion: "2.0#200",
            screenFingerprint: "screen-a",
            fieldShapeFingerprint: "field-a"
        )

        store.updateOffset(
            x: 4,
            y: -3,
            for: bundleIdentifier,
            reason: "screenshot-visual-correction",
            visualTrustContext: context,
            confidence: 0.86
        )
        store.recordObservation(for: bundleIdentifier, reason: "suggestion-presented")

        let profile = store.profile(for: bundleIdentifier)
        let adjustment = store.engine()
            .adjustment(for: bundleIdentifier, profileRenderMode: .inlineAdjacent)
            .trustedVisualOffsetOnly(context: context)
        let rect = CGRect(x: 100, y: 200, width: 0, height: 20)

        #expect(profile?.lastReason == "screenshot-visual-correction")
        #expect(adjustment.adjusted(rect) == CGRect(x: 104, y: 197, width: 0, height: 20))
    }
}

private final class StoreTestClock {
    var current: Date

    init(_ current: Date) {
        self.current = current
    }
}
