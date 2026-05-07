import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Compatibility learning")
struct CompatibilityLearningTests {
    @Test("Learning adjustment applies visual offsets")
    func appliesVisualOffsets() {
        let profile = CompatibilityLearningProfile(
            bundleIdentifier: "com.openai.codex",
            xOffset: 3,
            yOffset: -14,
            screenshotTracingEnabled: true,
            observations: 4,
            confidence: 0.7
        )
        let engine = CompatibilityLearningEngine(profiles: [profile.bundleIdentifier: profile])
        let adjustment = engine.adjustment(
            for: "com.openai.codex",
            profileRenderMode: .inlineAdjacent
        )

        let rect = adjustment.adjusted(CGRect(x: 100, y: 200, width: 0, height: 20))

        #expect(rect == CGRect(x: 103, y: 186, width: 0, height: 20))
        #expect(adjustment.shouldCaptureScreenshot)
        #expect(adjustment.metadata["learningApplied"] == "true")
        #expect(adjustment.metadata["learningYOffset"] == "-14.0")
    }

    @Test("Learning can override render mode")
    func overridesRenderMode() {
        let profile = CompatibilityLearningProfile(
            bundleIdentifier: "md.obsidian",
            renderModeOverride: .floatingMirror
        )
        let engine = CompatibilityLearningEngine(profiles: [profile.bundleIdentifier: profile])
        let adjustment = engine.adjustment(
            for: "md.obsidian",
            profileRenderMode: .inlineAdjacent
        )

        #expect(adjustment.effectiveRenderMode == .floatingMirror)
        #expect(adjustment.metadata["learningApplied"] == "true")
        #expect(adjustment.metadata["learningRenderMode"] == "floatingMirror")
    }

    @Test("Learning can ignore untrusted visual offsets")
    func canIgnoreUntrustedVisualOffsets() {
        let profile = CompatibilityLearningProfile(
            bundleIdentifier: "com.openai.codex",
            xOffset: -12,
            yOffset: 14,
            observations: 1,
            confidence: 0.2,
            lastReason: "old-debug-offset"
        )
        let engine = CompatibilityLearningEngine(profiles: [profile.bundleIdentifier: profile])
        let adjustment = engine.adjustment(
            for: "com.openai.codex",
            profileRenderMode: .inlineAdjacent
        ).trustedVisualOffsetOnly

        let rect = CGRect(x: 100, y: 200, width: 0, height: 20)

        #expect(adjustment.adjusted(rect) == rect)
        #expect(adjustment.metadata["learningXOffset"] == "0.0")
        #expect(adjustment.metadata["learningYOffset"] == "0.0")
        #expect(adjustment.metadata["learningVisualOffsetTrusted"] == "false")
    }

    @Test("Learning keeps manual visual nudges for synthetic caret apps")
    func keepsManualVisualNudges() {
        let profile = CompatibilityLearningProfile(
            bundleIdentifier: "com.openai.codex",
            xOffset: 6,
            yOffset: -4,
            observations: 1,
            confidence: 0.35,
            lastReason: "manual-visual-nudge"
        )
        let engine = CompatibilityLearningEngine(profiles: [profile.bundleIdentifier: profile])
        let adjustment = engine.adjustment(
            for: "com.openai.codex",
            profileRenderMode: .inlineAdjacent
        ).trustedVisualOffsetOnly

        let rect = CGRect(x: 100, y: 200, width: 0, height: 20)

        #expect(adjustment.adjusted(rect) == CGRect(x: 106, y: 196, width: 0, height: 20))
        #expect(adjustment.metadata["learningVisualOffsetTrusted"] == "true")
    }

    @Test("Learning ignores generic high confidence visual offsets")
    func ignoresGenericHighConfidenceVisualOffsets() {
        let profile = CompatibilityLearningProfile(
            bundleIdentifier: "md.obsidian",
            xOffset: -3,
            yOffset: 8,
            observations: 4,
            confidence: 0.7,
            lastReason: "placement-review"
        )
        let engine = CompatibilityLearningEngine(profiles: [profile.bundleIdentifier: profile])
        let adjustment = engine.adjustment(
            for: "md.obsidian",
            profileRenderMode: .inlineAdjacent
        ).trustedVisualOffsetOnly

        let rect = CGRect(x: 100, y: 200, width: 0, height: 20)

        #expect(adjustment.adjusted(rect) == rect)
        #expect(adjustment.metadata["learningVisualOffsetTrusted"] == "false")
    }

    @Test("Learning keeps screenshot visual corrections")
    func keepsScreenshotVisualCorrections() {
        let profile = CompatibilityLearningProfile(
            bundleIdentifier: "md.obsidian",
            xOffset: -3,
            yOffset: 8,
            observations: 4,
            confidence: 0.7,
            lastReason: "screenshot-visual-correction"
        )
        let engine = CompatibilityLearningEngine(profiles: [profile.bundleIdentifier: profile])
        let adjustment = engine.adjustment(
            for: "md.obsidian",
            profileRenderMode: .inlineAdjacent
        ).trustedVisualOffsetOnly

        let rect = CGRect(x: 100, y: 200, width: 0, height: 20)

        #expect(adjustment.adjusted(rect) == CGRect(x: 97, y: 208, width: 0, height: 20))
        #expect(adjustment.metadata["learningVisualOffsetTrusted"] == "true")
    }

    @Test("Learning keeps screenshot visual corrections from detector")
    func keepsScreenshotVisualCorrectionsFromDetector() {
        let detection = ScreenshotPlacementOffsetDetection(
            dx: 4,
            dy: -6,
            confidence: 0.91,
            signalPixelCount: 64,
            signalBounds: CGRect(x: 24, y: 12, width: 16, height: 4),
            reason: .detected
        )
        let correction = VisualPlacementCorrectionPolicy().correction(
            dx: detection.dx,
            dy: detection.dy,
            observations: 3,
            confidence: detection.confidence
        )
        let profile = CompatibilityLearningProfile(
            bundleIdentifier: "md.obsidian",
            xOffset: correction.dx,
            yOffset: correction.dy,
            observations: 3,
            confidence: detection.confidence,
            lastReason: "screenshot-visual-correction"
        )
        let engine = CompatibilityLearningEngine(profiles: [profile.bundleIdentifier: profile])
        let adjustment = engine.adjustment(
            for: "md.obsidian",
            profileRenderMode: .inlineAdjacent
        ).trustedVisualOffsetOnly

        let rect = CGRect(x: 100, y: 200, width: 0, height: 20)

        #expect(correction.decision == .accepted)
        #expect(adjustment.adjusted(rect) == CGRect(x: 104, y: 194, width: 0, height: 20))
        #expect(adjustment.metadata["learningVisualOffsetTrusted"] == "true")
        #expect(adjustment.metadata["learningConfidence"] == "0.91")
    }

    @Test("Missing learning profile leaves geometry alone")
    func missingProfileLeavesGeometryAlone() {
        let engine = CompatibilityLearningEngine()
        let adjustment = engine.adjustment(
            for: "com.apple.TextEdit",
            profileRenderMode: .inlineAdjacent
        )

        let rect = CGRect(x: 40, y: 50, width: 0, height: 20)

        #expect(adjustment.adjusted(rect) == rect)
        #expect(!adjustment.shouldCaptureScreenshot)
        #expect(adjustment.metadata["learningApplied"] == "false")
    }
}
