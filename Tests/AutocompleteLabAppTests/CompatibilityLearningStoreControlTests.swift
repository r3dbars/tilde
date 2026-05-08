import CoreGraphics
import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Compatibility learning store controls")
struct CompatibilityLearningStoreControlTests {
    @Test("Render mode override can force mirror and return to profile mode")
    func renderModeOverrideCanForceMirrorAndReturnToProfileMode() {
        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("CompatibilityLearningStoreControlTests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: temporaryFolder)
        }

        let store = CompatibilityLearningStore(
            fileURL: temporaryFolder.appendingPathComponent("compatibility-learning.json")
        )
        let bundleIdentifier = "com.example.editor"

        store.setRenderModeOverride(.floatingMirror, for: bundleIdentifier)

        var profile = store.profile(for: bundleIdentifier)
        #expect(profile?.renderModeOverride == .floatingMirror)
        #expect(profile?.lastReason == "mirror-mode-forced")
        #expect(
            store.engine()
                .adjustment(for: bundleIdentifier, profileRenderMode: .inlineAdjacent)
                .effectiveRenderMode == .floatingMirror
        )

        store.setRenderModeOverride(nil, for: bundleIdentifier)

        profile = store.profile(for: bundleIdentifier)
        #expect(profile?.renderModeOverride == nil)
        #expect(profile?.lastReason == "profile-mode-restored")
        #expect(
            store.engine()
                .adjustment(for: bundleIdentifier, profileRenderMode: .inlineAdjacent)
                .effectiveRenderMode == .inlineAdjacent
        )
    }

    @Test("Manual visual nudges store the current visual scope")
    func manualVisualNudgesStoreCurrentVisualScope() {
        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("CompatibilityLearningStoreScopeTests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: temporaryFolder)
        }

        let store = CompatibilityLearningStore(
            fileURL: temporaryFolder.appendingPathComponent("compatibility-learning.json")
        )
        let bundleIdentifier = "com.example.editor"
        let scope = CompatibilityLearningVisualScope(
            appVersion: "com.example.editor:1.0:10",
            screen: "1440x900@200",
            fieldShape: "role=AXTextArea;element=w=600,h=300"
        )
        let changedScope = CompatibilityLearningVisualScope(
            appVersion: "com.example.editor:1.0:10",
            screen: "1920x1080@200",
            fieldShape: "role=AXTextArea;element=w=600,h=300"
        )
        let rect = CGRect(x: 100, y: 200, width: 0, height: 20)

        store.nudgeOffset(dx: 2, dy: -4, for: bundleIdentifier, visualScope: scope)

        let profile = store.profile(for: bundleIdentifier)
        #expect(profile?.xOffset == 2)
        #expect(profile?.yOffset == -4)
        #expect(profile?.visualScope == scope)
        #expect(profile?.lastReason == "manual-visual-nudge")
        #expect(
            store.engine()
                .adjustment(for: bundleIdentifier, profileRenderMode: .inlineAdjacent)
                .trustedVisualOffsetOnly(matching: scope)
                .adjusted(rect) == CGRect(x: 102, y: 196, width: 0, height: 20)
        )
        #expect(
            store.engine()
                .adjustment(for: bundleIdentifier, profileRenderMode: .inlineAdjacent)
                .trustedVisualOffsetOnly(matching: changedScope)
                .adjusted(rect) == rect
        )
    }

    @Test("Direct visual offset updates store the current visual scope")
    func directVisualOffsetUpdatesStoreCurrentVisualScope() {
        let temporaryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("CompatibilityLearningStoreUpdateScopeTests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: temporaryFolder)
        }

        let store = CompatibilityLearningStore(
            fileURL: temporaryFolder.appendingPathComponent("compatibility-learning.json")
        )
        let bundleIdentifier = "com.example.editor"
        let scope = CompatibilityLearningVisualScope(
            appVersion: "com.example.editor:1.0:10",
            screen: "1440x900@200",
            fieldShape: "role=AXTextArea;element=w=600,h=300"
        )

        store.updateOffset(
            x: 6,
            y: -8,
            for: bundleIdentifier,
            reason: "screenshot-visual-correction",
            visualScope: scope
        )

        let profile = store.profile(for: bundleIdentifier)
        #expect(profile?.xOffset == 6)
        #expect(profile?.yOffset == -8)
        #expect(profile?.visualScope == scope)
        #expect(profile?.lastReason == "screenshot-visual-correction")
    }
}
