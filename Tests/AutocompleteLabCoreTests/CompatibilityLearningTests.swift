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

    @Test("Learning ignores unsafe render mode overrides")
    func ignoresUnsafeRenderModeOverrides() {
        let notesProfile = CompatibilityLearningProfile(
            bundleIdentifier: "com.apple.Notes",
            renderModeOverride: .inlineAdjacent
        )
        let mailProfile = CompatibilityLearningProfile(
            bundleIdentifier: "com.apple.mail",
            renderModeOverride: .floatingMirror
        )
        let engine = CompatibilityLearningEngine(profiles: [
            notesProfile.bundleIdentifier: notesProfile,
            mailProfile.bundleIdentifier: mailProfile
        ])

        let notesAdjustment = engine.adjustment(
            for: "com.apple.Notes",
            profileRenderMode: .floatingMirror
        )
        let mailAdjustment = engine.adjustment(
            for: "com.apple.mail",
            profileRenderMode: .disabled
        )

        #expect(notesAdjustment.effectiveRenderMode == .floatingMirror)
        #expect(notesAdjustment.metadata["learningApplied"] == "false")
        #expect(notesAdjustment.metadata["learningRenderModeOverrideIgnored"] == "true")
        #expect(mailAdjustment.effectiveRenderMode == .disabled)
        #expect(mailAdjustment.metadata["learningApplied"] == "false")
        #expect(mailAdjustment.metadata["learningRenderModeOverrideIgnored"] == "true")
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
        let scope = CompatibilityLearningVisualScope(
            appVersion: "com.openai.codex:1.0:10",
            screen: "1440x900@200",
            fieldShape: "role=AXTextArea;element=w=600,h=300"
        )
        let profile = CompatibilityLearningProfile(
            bundleIdentifier: "com.openai.codex",
            xOffset: 6,
            yOffset: -4,
            visualScope: scope,
            observations: 1,
            confidence: 0.35,
            lastReason: "manual-visual-nudge"
        )
        let engine = CompatibilityLearningEngine(profiles: [profile.bundleIdentifier: profile])
        let adjustment = engine.adjustment(
            for: "com.openai.codex",
            profileRenderMode: .inlineAdjacent
        ).trustedVisualOffsetOnly(matching: scope)

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
        let scope = CompatibilityLearningVisualScope(
            appVersion: "md.obsidian:1.0:10",
            screen: "1440x900@200",
            fieldShape: "role=AXTextArea;element=w=600,h=300"
        )
        let profile = CompatibilityLearningProfile(
            bundleIdentifier: "md.obsidian",
            xOffset: -3,
            yOffset: 8,
            visualScope: scope,
            observations: 4,
            confidence: 0.7,
            lastReason: "screenshot-visual-correction"
        )
        let engine = CompatibilityLearningEngine(profiles: [profile.bundleIdentifier: profile])
        let adjustment = engine.adjustment(
            for: "md.obsidian",
            profileRenderMode: .inlineAdjacent
        ).trustedVisualOffsetOnly(matching: scope)

        let rect = CGRect(x: 100, y: 200, width: 0, height: 20)

        #expect(adjustment.adjusted(rect) == CGRect(x: 97, y: 208, width: 0, height: 20))
        #expect(adjustment.metadata["learningVisualOffsetTrusted"] == "true")
    }

    @Test("Learning ignores unscoped screenshot visual corrections")
    func ignoresUnscopedScreenshotVisualCorrections() {
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

        #expect(adjustment.adjusted(rect) == rect)
        #expect(adjustment.metadata["learningVisualOffsetTrusted"] == "false")
    }

    @Test("Learning expires trusted visual offsets when visual scope changes")
    func expiresTrustedVisualOffsetsWhenVisualScopeChanges() {
        let originalScope = CompatibilityLearningVisualScope(
            appVersion: "com.example.Editor:1.0:10",
            screen: "1440x900@200",
            fieldShape: "role=AXTextArea;element=w=600,h=300"
        )
        let changedScope = CompatibilityLearningVisualScope(
            appVersion: "com.example.Editor:1.1:11",
            screen: "1440x900@200",
            fieldShape: "role=AXTextArea;element=w=600,h=300"
        )
        let profile = CompatibilityLearningProfile(
            bundleIdentifier: "com.example.Editor",
            xOffset: 8,
            yOffset: -2,
            visualScope: originalScope,
            lastReason: "manual-visual-nudge"
        )
        let engine = CompatibilityLearningEngine(profiles: [profile.bundleIdentifier: profile])
        let rect = CGRect(x: 100, y: 200, width: 0, height: 20)

        let matchingAdjustment = engine.adjustment(
            for: profile.bundleIdentifier,
            profileRenderMode: .inlineAdjacent
        ).trustedVisualOffsetOnly(matching: originalScope)
        let changedAdjustment = engine.adjustment(
            for: profile.bundleIdentifier,
            profileRenderMode: .inlineAdjacent
        ).trustedVisualOffsetOnly(matching: changedScope)

        #expect(matchingAdjustment.adjusted(rect) == CGRect(x: 108, y: 198, width: 0, height: 20))
        #expect(matchingAdjustment.metadata["learningVisualOffsetTrusted"] == "true")
        #expect(changedAdjustment.adjusted(rect) == rect)
        #expect(changedAdjustment.metadata["learningVisualOffsetTrusted"] == "false")
    }

    @Test("Learning expires trusted visual offsets when current visual scope is missing")
    func expiresTrustedVisualOffsetsWhenCurrentVisualScopeIsMissing() {
        let storedScope = CompatibilityLearningVisualScope(
            appVersion: "com.example.Editor:1.0:10",
            screen: "1440x900@200",
            fieldShape: "role=AXTextArea;element=w=600,h=300"
        )
        let profile = CompatibilityLearningProfile(
            bundleIdentifier: "com.example.Editor",
            xOffset: 8,
            yOffset: -2,
            visualScope: storedScope,
            lastReason: "screenshot-visual-correction"
        )
        let engine = CompatibilityLearningEngine(profiles: [profile.bundleIdentifier: profile])
        let rect = CGRect(x: 100, y: 200, width: 0, height: 20)

        let adjustment = engine.adjustment(
            for: profile.bundleIdentifier,
            profileRenderMode: .inlineAdjacent
        ).trustedVisualOffsetOnly(matching: nil)

        #expect(adjustment.adjusted(rect) == rect)
        #expect(adjustment.metadata["learningXOffset"] == "0.0")
        #expect(adjustment.metadata["learningVisualOffsetTrusted"] == "false")
    }

    @Test("Unscoped trusted visual offsets do not apply in scoped live mode")
    func unscopedTrustedVisualOffsetsDoNotApplyInScopedLiveMode() {
        let currentScope = CompatibilityLearningVisualScope(
            appVersion: "com.example.Editor:1.0:10",
            screen: "1440x900@200",
            fieldShape: "role=AXTextArea;element=w=600,h=300"
        )
        let profile = CompatibilityLearningProfile(
            bundleIdentifier: "com.example.Editor",
            xOffset: 8,
            yOffset: -2,
            lastReason: "screenshot-visual-correction"
        )
        let engine = CompatibilityLearningEngine(profiles: [profile.bundleIdentifier: profile])
        let rect = CGRect(x: 100, y: 200, width: 0, height: 20)

        let adjustment = engine.adjustment(
            for: profile.bundleIdentifier,
            profileRenderMode: .inlineAdjacent
        ).trustedVisualOffsetOnly(matching: currentScope)

        #expect(adjustment.adjusted(rect) == rect)
        #expect(adjustment.metadata["learningVisualOffsetTrusted"] == "false")
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

    @Test("Learning expires visual offsets when trust context changes")
    func expiresVisualOffsetsWhenTrustContextChanges() {
        let profile = CompatibilityLearningProfile(
            bundleIdentifier: "md.obsidian",
            xOffset: 7,
            yOffset: -5,
            visualAppVersion: "1.2.3",
            visualScreenFingerprint: "screen-a",
            visualFieldShapeFingerprint: "field-a",
            observations: 4,
            confidence: 0.8,
            lastReason: "screenshot-visual-correction"
        )
        let engine = CompatibilityLearningEngine(profiles: [profile.bundleIdentifier: profile])
        let matching = CompatibilityLearningVisualTrustContext(
            appVersion: "1.2.3",
            screenFingerprint: "screen-a",
            fieldShapeFingerprint: "field-a"
        )
        let movedScreen = CompatibilityLearningVisualTrustContext(
            appVersion: "1.2.3",
            screenFingerprint: "screen-b",
            fieldShapeFingerprint: "field-a"
        )
        let rect = CGRect(x: 100, y: 200, width: 0, height: 20)

        let trusted = engine.adjustment(
            for: "md.obsidian",
            profileRenderMode: .inlineAdjacent
        ).trustedVisualOffsetOnly(context: matching)
        let expired = engine.adjustment(
            for: "md.obsidian",
            profileRenderMode: .inlineAdjacent
        ).trustedVisualOffsetOnly(context: movedScreen)

        #expect(trusted.adjusted(rect) == CGRect(x: 107, y: 195, width: 0, height: 20))
        #expect(trusted.metadata["learningVisualOffsetTrusted"] == "true")
        #expect(expired.adjusted(rect) == rect)
        #expect(expired.metadata["learningVisualOffsetTrusted"] == "false")
    }

    @Test("Legacy visual offsets stay trusted until resaved with context")
    func legacyVisualOffsetsStayTrustedUntilResavedWithContext() {
        let profile = CompatibilityLearningProfile(
            bundleIdentifier: "md.obsidian",
            xOffset: 2,
            yOffset: 3,
            observations: 4,
            confidence: 0.7,
            lastReason: "screenshot-visual-correction"
        )
        let context = CompatibilityLearningVisualTrustContext(
            appVersion: "1.2.3",
            screenFingerprint: "screen-b",
            fieldShapeFingerprint: "field-b"
        )
        let engine = CompatibilityLearningEngine(profiles: [profile.bundleIdentifier: profile])
        let adjustment = engine.adjustment(
            for: "md.obsidian",
            profileRenderMode: .inlineAdjacent
        ).trustedVisualOffsetOnly(context: context)

        #expect(adjustment.adjusted(CGRect(x: 100, y: 200, width: 0, height: 20))
            == CGRect(x: 102, y: 203, width: 0, height: 20))
        #expect(adjustment.metadata["learningVisualOffsetTrusted"] == "true")
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

    @Test("Placement trust policy allows low confidence only for green or trusted visual proof")
    func placementTrustPolicyAllowsLowConfidenceOnlyForGreenOrTrustedVisualProof() {
        let store = CompatibilityProfileStore.mvp
        let textEdit = store.profile(for: "com.apple.TextEdit")!
        let notes = store.profile(for: "com.apple.Notes")!

        let greenPolicy = PlacementTrustPolicy.compatibility(
            profile: textEdit,
            learningAdjustment: CompatibilityLearningAdjustment(
                profile: nil,
                effectiveRenderMode: textEdit.renderMode
            )
        )
        #expect(greenPolicy.allowsLowConfidencePlacement)
        #expect(greenPolicy.allowsSyntheticCaretPlacement)
        #expect(greenPolicy.allowsDetachedAnchorPlacement)

        let unprovenPolicy = PlacementTrustPolicy.compatibility(
            profile: notes,
            learningAdjustment: CompatibilityLearningAdjustment(
                profile: nil,
                effectiveRenderMode: notes.renderMode
            )
        )
        #expect(!unprovenPolicy.allowsLowConfidencePlacement)
        #expect(!unprovenPolicy.allowsSyntheticCaretPlacement)
        #expect(!unprovenPolicy.allowsDetachedAnchorPlacement)

        let untrustedLearningPolicy = PlacementTrustPolicy.compatibility(
            profile: notes,
            learningAdjustment: CompatibilityLearningAdjustment(
                profile: CompatibilityLearningProfile(
                    bundleIdentifier: notes.bundleIdentifier,
                    xOffset: 2,
                    yOffset: 0,
                    observations: 4,
                    confidence: 0.9,
                    lastReason: "observation"
                ),
                effectiveRenderMode: notes.renderMode
            )
        )
        #expect(!untrustedLearningPolicy.allowsLowConfidencePlacement)
        #expect(!untrustedLearningPolicy.allowsSyntheticCaretPlacement)
        #expect(!untrustedLearningPolicy.allowsDetachedAnchorPlacement)

        let trustedLearningPolicy = PlacementTrustPolicy.compatibility(
            profile: notes,
            learningAdjustment: CompatibilityLearningAdjustment(
                profile: CompatibilityLearningProfile(
                    bundleIdentifier: notes.bundleIdentifier,
                    xOffset: 2,
                    yOffset: 0,
                    visualScope: CompatibilityLearningVisualScope(
                        appVersion: "com.apple.Notes:1.0:10",
                        screen: "1440x900@200",
                        fieldShape: "role=AXTextArea;element=w=600,h=300"
                    ),
                    observations: 4,
                    confidence: 0.9,
                    lastReason: "screenshot-visual-correction"
                ),
                effectiveRenderMode: notes.renderMode
            )
        )
        #expect(trustedLearningPolicy.allowsLowConfidencePlacement)
        #expect(trustedLearningPolicy.allowsSyntheticCaretPlacement)
        #expect(trustedLearningPolicy.allowsDetachedAnchorPlacement)
    }
}
