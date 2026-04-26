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
