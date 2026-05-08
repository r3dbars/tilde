import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Visual placement geometry correction policy")
struct VisualPlacementGeometryCorrectionPolicyTests {
    @Test("Accepts trusted screenshot corrections")
    func acceptsTrustedScreenshotCorrections() {
        let correction = VisualPlacementCorrectionPolicy().correction(
            dx: 4,
            dy: -8,
            observations: 3,
            confidence: 0.72
        )
        let rect = CGRect(x: 100, y: 200, width: 0, height: 20)

        #expect(correction.decision == .accepted)
        #expect(correction.reason == .trusted)
        #expect(correction.adjusted(rect) == CGRect(x: 104, y: 192, width: 0, height: 20))
    }

    @Test("Rejects low confidence screenshot noise")
    func rejectsLowConfidenceScreenshotNoise() {
        let correction = VisualPlacementCorrectionPolicy().correction(
            dx: 10,
            dy: -6,
            observations: 1,
            confidence: 0.25
        )
        let rect = CGRect(x: 100, y: 200, width: 0, height: 20)

        #expect(correction.decision == .rejected)
        #expect(correction.reason == .insufficientEvidence)
        #expect(correction.adjusted(rect) == rect)
    }

    @Test("Rejects subpixel jitter")
    func rejectsSubpixelJitter() {
        let correction = VisualPlacementCorrectionPolicy().correction(
            dx: 0.25,
            dy: -0.25,
            observations: 8,
            confidence: 0.9
        )

        #expect(correction.decision == .rejected)
        #expect(correction.reason == .subpixelNoise)
    }

    @Test("Clamps large trusted corrections")
    func clampsLargeTrustedCorrections() {
        let correction = VisualPlacementCorrectionPolicy().correction(
            dx: 40,
            dy: 30,
            observations: 5,
            confidence: 0.8
        )

        #expect(correction.decision == .clamped)
        #expect(correction.reason == .clampedToSafeRange)
        #expect(abs(correction.dx - 19.2) < 0.001)
        #expect(abs(correction.dy - 14.4) < 0.001)
    }

    @Test("Rejects extreme visual outliers")
    func rejectsExtremeVisualOutliers() {
        let correction = VisualPlacementCorrectionPolicy().correction(
            dx: 140,
            dy: 20,
            observations: 12,
            confidence: 0.96
        )

        #expect(correction.decision == .rejected)
        #expect(correction.reason == .excessiveOutlier)
    }

    @Test("Allows explicit manual correction without repeated observations")
    func allowsExplicitManualCorrection() {
        let correction = VisualPlacementCorrectionPolicy().correction(
            dx: -6,
            dy: 4,
            observations: 1,
            confidence: 0.1,
            allowManualOverride: true
        )

        #expect(correction.decision == .accepted)
        #expect(correction.reason == .trusted)
    }

    @Test("Accepts detector output through the same trust gate")
    func acceptsDetectorOutputThroughTrustGate() {
        let detection = ScreenshotPlacementOffsetDetection(
            dx: 5,
            dy: -2,
            confidence: 0.86,
            signalPixelCount: 48,
            signalBounds: CGRect(x: 30, y: 18, width: 12, height: 4),
            reason: .detected
        )

        let correction = VisualPlacementCorrectionPolicy().correction(
            dx: detection.dx,
            dy: detection.dy,
            observations: 3,
            confidence: detection.confidence
        )

        #expect(correction.decision == .accepted)
        #expect(correction.reason == .trusted)
        #expect(correction.dx == 5)
        #expect(correction.dy == -2)
    }

    @Test("Rejects non-finite corrections")
    func rejectsNonFiniteCorrections() {
        let correction = VisualPlacementCorrectionPolicy().correction(
            dx: CGFloat.nan,
            dy: 4,
            observations: 8,
            confidence: 0.9
        )

        #expect(correction.decision == .rejected)
        #expect(correction.reason == .nonFiniteInput)
    }
}
