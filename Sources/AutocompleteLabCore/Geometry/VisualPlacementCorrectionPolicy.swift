import CoreGraphics
import Foundation

public enum VisualPlacementCorrectionDecision: String, Equatable, Sendable {
    case accepted
    case clamped
    case rejected
}

public enum VisualPlacementCorrectionReason: String, Equatable, Sendable {
    case trusted
    case clampedToSafeRange = "clamped-to-safe-range"
    case subpixelNoise = "subpixel-noise"
    case insufficientEvidence = "insufficient-evidence"
    case nonFiniteInput = "non-finite-input"
    case excessiveOutlier = "excessive-outlier"
}

public enum VisualPlacementCorrectionProofOutcome: String, Equatable, Sendable {
    case improved
    case refused
    case unchanged
}

public struct VisualPlacementCorrectionProof: Equatable, Sendable {
    public let outcome: VisualPlacementCorrectionProofOutcome
    public let beforeDistance: CGFloat
    public let afterDistance: CGFloat
    public let improvement: CGFloat
    public let privacyBoundary: String

    public init(
        outcome: VisualPlacementCorrectionProofOutcome,
        beforeDistance: CGFloat,
        afterDistance: CGFloat,
        improvement: CGFloat,
        privacyBoundary: String = "geometry-only"
    ) {
        self.outcome = outcome
        self.beforeDistance = beforeDistance
        self.afterDistance = afterDistance
        self.improvement = improvement
        self.privacyBoundary = privacyBoundary
    }
}

public struct VisualPlacementCorrection: Equatable, Sendable {
    public let dx: CGFloat
    public let dy: CGFloat
    public let decision: VisualPlacementCorrectionDecision
    public let reason: VisualPlacementCorrectionReason

    public init(
        dx: CGFloat,
        dy: CGFloat,
        decision: VisualPlacementCorrectionDecision,
        reason: VisualPlacementCorrectionReason
    ) {
        self.dx = dx
        self.dy = dy
        self.decision = decision
        self.reason = reason
    }

    public var isApplied: Bool {
        decision != .rejected
    }

    public func adjusted(_ rect: CGRect?) -> CGRect? {
        guard let rect, isApplied else {
            return rect
        }

        return rect.offsetBy(dx: dx, dy: dy)
    }

    public func proof(
        measuredDX: CGFloat,
        measuredDY: CGFloat
    ) -> VisualPlacementCorrectionProof {
        guard measuredDX.isFinite, measuredDY.isFinite else {
            return VisualPlacementCorrectionProof(
                outcome: .refused,
                beforeDistance: 0,
                afterDistance: 0,
                improvement: 0
            )
        }

        let before = CGFloat(Foundation.hypot(Double(measuredDX), Double(measuredDY)))
        guard isApplied else {
            return VisualPlacementCorrectionProof(
                outcome: .refused,
                beforeDistance: before,
                afterDistance: before,
                improvement: 0
            )
        }

        let residualDX = measuredDX - dx
        let residualDY = measuredDY - dy
        let after = CGFloat(Foundation.hypot(Double(residualDX), Double(residualDY)))
        let improvement = max(0, before - after)
        return VisualPlacementCorrectionProof(
            outcome: improvement > 0 ? .improved : .unchanged,
            beforeDistance: before,
            afterDistance: after,
            improvement: improvement
        )
    }
}

public struct VisualPlacementCorrectionPolicy: Equatable, Sendable {
    public let minimumMeaningfulDistance: CGFloat
    public let maximumAppliedDistance: CGFloat
    public let maximumObservedDistance: CGFloat
    public let minimumConfidence: Double
    public let minimumObservations: Int

    public init(
        minimumMeaningfulDistance: CGFloat = 0.75,
        maximumAppliedDistance: CGFloat = 24,
        maximumObservedDistance: CGFloat = 96,
        minimumConfidence: Double = 0.6,
        minimumObservations: Int = 3
    ) {
        self.minimumMeaningfulDistance = minimumMeaningfulDistance
        self.maximumAppliedDistance = maximumAppliedDistance
        self.maximumObservedDistance = maximumObservedDistance
        self.minimumConfidence = minimumConfidence
        self.minimumObservations = minimumObservations
    }

    public func correction(
        dx: CGFloat,
        dy: CGFloat,
        observations: Int,
        confidence: Double,
        allowManualOverride: Bool = false
    ) -> VisualPlacementCorrection {
        guard dx.isFinite,
              dy.isFinite,
              confidence.isFinite,
              minimumMeaningfulDistance.isFinite,
              maximumAppliedDistance.isFinite,
              maximumObservedDistance.isFinite else {
            return rejected(reason: .nonFiniteInput)
        }

        let distance = hypot(dx, dy)

        guard distance >= max(0, minimumMeaningfulDistance) else {
            return rejected(reason: .subpixelNoise)
        }

        guard allowManualOverride || (observations >= minimumObservations && confidence >= minimumConfidence) else {
            return rejected(reason: .insufficientEvidence)
        }

        let appliedLimit = max(0, maximumAppliedDistance)
        guard appliedLimit > 0 else {
            return rejected(reason: .excessiveOutlier)
        }

        let observedLimit = max(appliedLimit, maximumObservedDistance)

        guard distance <= observedLimit else {
            return rejected(reason: .excessiveOutlier)
        }

        guard distance > appliedLimit else {
            return VisualPlacementCorrection(
                dx: dx,
                dy: dy,
                decision: .accepted,
                reason: .trusted
            )
        }

        let scale = appliedLimit / distance
        return VisualPlacementCorrection(
            dx: dx * scale,
            dy: dy * scale,
            decision: .clamped,
            reason: .clampedToSafeRange
        )
    }

    private func hypot(_ dx: CGFloat, _ dy: CGFloat) -> CGFloat {
        CGFloat(Foundation.hypot(Double(dx), Double(dy)))
    }

    private func rejected(reason: VisualPlacementCorrectionReason) -> VisualPlacementCorrection {
        VisualPlacementCorrection(
            dx: 0,
            dy: 0,
            decision: .rejected,
            reason: reason
        )
    }
}
