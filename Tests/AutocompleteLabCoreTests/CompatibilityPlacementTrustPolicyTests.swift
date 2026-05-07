import Testing
@testable import AutocompleteLabCore

@Suite("Compatibility placement trust policy")
struct CompatibilityPlacementTrustPolicyTests {
    @Test("Chrome allows synthetic caret placement without opening low-confidence fallback")
    func chromeAllowsSyntheticCaretPlacementWithoutOpeningLowConfidenceFallback() throws {
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))
        let policy = CompatibilityPlacementTrustPolicy().policy(
            profile: chrome,
            learningAdjustment: CompatibilityLearningAdjustment(
                profile: nil,
                effectiveRenderMode: chrome.renderMode
            )
        )

        #expect(policy.allowsSyntheticCaretPlacement)
        #expect(!policy.allowsLowConfidencePlacement)
    }

    @Test("Prompt apps still block synthetic caret placement until trusted proof exists")
    func promptAppsStillBlockSyntheticCaretPlacementUntilTrustedProofExists() throws {
        let codex = try #require(CompatibilityProfileStore.mvp.profile(for: "com.openai.codex"))
        let untrustedPolicy = CompatibilityPlacementTrustPolicy().policy(
            profile: codex,
            learningAdjustment: CompatibilityLearningAdjustment(
                profile: nil,
                effectiveRenderMode: codex.renderMode
            )
        )

        #expect(!untrustedPolicy.allowsSyntheticCaretPlacement)
        #expect(!untrustedPolicy.allowsLowConfidencePlacement)
    }

    @Test("Trusted visual adjustments can unlock app-specific fallback placement")
    func trustedVisualAdjustmentsCanUnlockAppSpecificFallbackPlacement() throws {
        let codex = try #require(CompatibilityProfileStore.mvp.profile(for: "com.openai.codex"))
        let trustedPolicy = CompatibilityPlacementTrustPolicy().policy(
            profile: codex,
            learningAdjustment: CompatibilityLearningAdjustment(
                profile: CompatibilityLearningProfile(
                    bundleIdentifier: codex.bundleIdentifier,
                    xOffset: 3,
                    yOffset: 0,
                    lastReason: "manual-visual-nudge"
                ),
                effectiveRenderMode: codex.renderMode
            )
        )

        #expect(trustedPolicy.allowsSyntheticCaretPlacement)
        #expect(trustedPolicy.allowsLowConfidencePlacement)
    }
}
