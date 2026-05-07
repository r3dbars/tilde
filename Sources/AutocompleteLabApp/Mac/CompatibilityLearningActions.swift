import AutocompleteLabCore
import Foundation

struct CompatibilityLearningNudgeResult: Equatable {
    let bundleIdentifier: String
    let dx: Double
    let dy: Double
    let appliedToVisibleSuggestion: Bool

    var metadata: [String: String] {
        [
            "app": bundleIdentifier,
            "dx": String(dx),
            "dy": String(dy),
            "appliedToVisibleSuggestion": String(appliedToVisibleSuggestion)
        ]
    }
}

struct CompatibilityLearningScreenshotToggleResult: Equatable {
    let bundleIdentifier: String
    let enabled: Bool

    var metadata: [String: String] {
        [
            "app": bundleIdentifier,
            "enabled": String(enabled)
        ]
    }
}

struct CompatibilityLearningResetResult: Equatable {
    let bundleIdentifier: String

    var metadata: [String: String] {
        ["app": bundleIdentifier]
    }
}

final class CompatibilityLearningActions {
    private let store: CompatibilityLearningStore
    private let profileStore: CompatibilityProfileStore

    init(
        store: CompatibilityLearningStore,
        profileStore: CompatibilityProfileStore
    ) {
        self.store = store
        self.profileStore = profileStore
    }

    func toggleScreenshotTracing(for bundleIdentifier: String) -> CompatibilityLearningScreenshotToggleResult? {
        guard !bundleIdentifier.isEmpty else {
            return nil
        }

        let enabled = !(store.profile(for: bundleIdentifier)?.screenshotTracingEnabled == true)
        store.setScreenshotTracing(enabled, for: bundleIdentifier)
        return CompatibilityLearningScreenshotToggleResult(
            bundleIdentifier: bundleIdentifier,
            enabled: enabled
        )
    }

    func nudge(
        dx: Double,
        dy: Double,
        visibleSuggestionBundleIdentifier: String?,
        fallbackBundleIdentifier: String?,
        applyVisibleSuggestionNudge: (String) -> Bool
    ) -> CompatibilityLearningNudgeResult? {
        guard let bundleIdentifier = visibleSuggestionBundleIdentifier ?? fallbackBundleIdentifier,
              profileStore.allows(bundleIdentifier: bundleIdentifier) else {
            return nil
        }

        store.nudgeOffset(dx: dx, dy: dy, for: bundleIdentifier)
        let appliedToVisibleSuggestion = applyVisibleSuggestionNudge(bundleIdentifier)

        return CompatibilityLearningNudgeResult(
            bundleIdentifier: bundleIdentifier,
            dx: dx,
            dy: dy,
            appliedToVisibleSuggestion: appliedToVisibleSuggestion
        )
    }

    func reset(
        visibleSuggestionBundleIdentifier: String?,
        fallbackBundleIdentifier: String?
    ) -> CompatibilityLearningResetResult? {
        guard let bundleIdentifier = visibleSuggestionBundleIdentifier ?? fallbackBundleIdentifier else {
            return nil
        }

        store.reset(bundleIdentifier: bundleIdentifier)
        return CompatibilityLearningResetResult(bundleIdentifier: bundleIdentifier)
    }
}
