import Foundation
import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabCore

@Suite("Compatibility learning actions")
struct CompatibilityLearningActionsTests {
    @Test("Screenshot tracing toggle uses the app profile state")
    func screenshotTracingToggleUsesAppProfileState() {
        let store = makeStore()
        let actions = CompatibilityLearningActions(store: store, profileStore: .mvp)

        let enabled = actions.toggleScreenshotTracing(for: "com.apple.TextEdit")
        #expect(enabled?.enabled == true)
        #expect(enabled?.metadata["app"] == "com.apple.TextEdit")
        #expect(store.profile(for: "com.apple.TextEdit")?.screenshotTracingEnabled == true)

        let disabled = actions.toggleScreenshotTracing(for: "com.apple.TextEdit")
        #expect(disabled?.enabled == false)
        #expect(store.profile(for: "com.apple.TextEdit")?.screenshotTracingEnabled == false)
        #expect(actions.toggleScreenshotTracing(for: "") == nil)
    }

    @Test("Nudge prefers visible suggestion app and applies visible movement")
    func nudgePrefersVisibleSuggestionAppAndAppliesVisibleMovement() {
        let store = makeStore()
        let actions = CompatibilityLearningActions(store: store, profileStore: .mvp)
        var appliedBundles: [String] = []

        let result = actions.nudge(
            dx: 2,
            dy: -4,
            visibleSuggestionBundleIdentifier: "com.apple.TextEdit",
            fallbackBundleIdentifier: "com.google.Chrome",
            applyVisibleSuggestionNudge: { bundleIdentifier in
                appliedBundles.append(bundleIdentifier)
                return true
            }
        )

        #expect(result?.bundleIdentifier == "com.apple.TextEdit")
        #expect(result?.appliedToVisibleSuggestion == true)
        #expect(result?.metadata["dx"] == "2.0")
        #expect(appliedBundles == ["com.apple.TextEdit"])
        #expect(store.profile(for: "com.apple.TextEdit")?.xOffset == 2)
        #expect(store.profile(for: "com.apple.TextEdit")?.yOffset == -4)
    }

    @Test("Nudge falls back to current app and skips unknown apps")
    func nudgeFallsBackToCurrentAppAndSkipsUnknownApps() {
        let store = makeStore()
        let actions = CompatibilityLearningActions(store: store, profileStore: .mvp)

        let fallback = actions.nudge(
            dx: 1,
            dy: 1,
            visibleSuggestionBundleIdentifier: nil,
            fallbackBundleIdentifier: "com.google.Chrome",
            applyVisibleSuggestionNudge: { _ in false }
        )
        #expect(fallback?.bundleIdentifier == "com.google.Chrome")
        #expect(fallback?.appliedToVisibleSuggestion == false)

        let skipped = actions.nudge(
            dx: 1,
            dy: 1,
            visibleSuggestionBundleIdentifier: "com.example.Unknown",
            fallbackBundleIdentifier: nil,
            applyVisibleSuggestionNudge: { _ in true }
        )
        #expect(skipped == nil)
    }

    @Test("Reset removes the selected learning profile")
    func resetRemovesSelectedLearningProfile() {
        let store = makeStore()
        let actions = CompatibilityLearningActions(store: store, profileStore: .mvp)
        store.nudgeOffset(dx: 3, dy: 3, for: "com.apple.TextEdit")

        let result = actions.reset(
            visibleSuggestionBundleIdentifier: nil,
            fallbackBundleIdentifier: "com.apple.TextEdit"
        )

        #expect(result?.bundleIdentifier == "com.apple.TextEdit")
        #expect(result?.metadata["app"] == "com.apple.TextEdit")
        #expect(store.profile(for: "com.apple.TextEdit") == nil)
        #expect(actions.reset(visibleSuggestionBundleIdentifier: nil, fallbackBundleIdentifier: nil) == nil)
    }

    private func makeStore() -> CompatibilityLearningStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return CompatibilityLearningStore(
            fileURL: directory.appendingPathComponent("compatibility-learning.json"),
            screenshotTracingDuration: 60,
            now: { Date(timeIntervalSince1970: 1_000) }
        )
    }
}
