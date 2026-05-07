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
}
