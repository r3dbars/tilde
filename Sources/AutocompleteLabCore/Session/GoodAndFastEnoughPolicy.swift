import Foundation

/// The single decision surface for a candidate that might reach the user.
///
/// Confidence, scored utility, latency, and command fallback remain individually
/// testable, but the app asks this policy for the final good-and-fast-enough
/// answer. This keeps the safety rules in core while native code owns only the
/// presentation and placement plumbing.
public struct GoodAndFastEnoughDecision: Equatable, Sendable {
    public let decision: DisplayScoreDecision
    public let confidence: CompletionConfidenceDecision
    public let latencyBudgetMilliseconds: Int
    public let measuredLatencyMilliseconds: Int
    public let metadata: [String: String]

    public init(
        decision: DisplayScoreDecision,
        confidence: CompletionConfidenceDecision,
        latencyBudgetMilliseconds: Int,
        measuredLatencyMilliseconds: Int,
        metadata: [String: String]
    ) {
        self.decision = decision
        self.confidence = confidence
        self.latencyBudgetMilliseconds = max(1, latencyBudgetMilliseconds)
        self.measuredLatencyMilliseconds = max(0, measuredLatencyMilliseconds)
        self.metadata = metadata
    }

    public var shouldDisplay: Bool {
        decision.shouldDisplay
    }
}

public struct GoodAndFastEnoughPolicy: Equatable, Sendable {
    public let completionConfidencePolicy: CompletionConfidencePolicy
    public let commandFallbackPolicy: CommandFallbackPolicy
    public let maximumDisplayLatencyMilliseconds: Int

    public init(
        completionConfidencePolicy: CompletionConfidencePolicy = CompletionConfidencePolicy(),
        commandFallbackPolicy: CommandFallbackPolicy = CommandFallbackPolicy()
    ) {
        self.completionConfidencePolicy = completionConfidencePolicy
        self.commandFallbackPolicy = commandFallbackPolicy
        self.maximumDisplayLatencyMilliseconds = completionConfidencePolicy.maximumDisplayLatencyMilliseconds
    }

    public func decision(
        suggestion: CompletionSuggestion,
        mode: CompletionRequestMode,
        textBeforeCursor: String,
        supportLevel: CompatibilitySupportLevel,
        score: DisplayScore,
        displayScorePolicy: DisplayScorePolicy,
        latencyMilliseconds: Int,
        latencyBudgetMilliseconds: Int? = nil,
        latencyForBudgetMilliseconds: Int? = nil,
        enforceLatencyCeiling: Bool = true,
        allowLatencyBypass: Bool = false,
        behaviorProfileID: AutocompleteBehaviorProfileID? = nil
    ) -> GoodAndFastEnoughDecision {
        let budget = max(1, latencyBudgetMilliseconds ?? maximumDisplayLatencyMilliseconds)
        let measuredLatency = max(0, latencyForBudgetMilliseconds ?? latencyMilliseconds)
        let confidence = completionConfidencePolicy.decision(
            suggestion: suggestion,
            mode: mode,
            textBeforeCursor: textBeforeCursor,
            latencyMilliseconds: latencyMilliseconds,
            supportLevel: supportLevel
        )
        let scoredDecision = displayScorePolicy.decision(
            for: score,
            mode: mode,
            behaviorProfileID: behaviorProfileID
        )

        var metadata = scoredDecision.metadata
        metadata["completionConfidenceBucket"] = confidence.bucket.rawValue
        metadata["completionConfidenceScore"] = String(confidence.score)
        metadata["completionConfidenceReasons"] = confidence.reasons.joined(separator: ",")
        metadata["modelDisplayLatencyBudgetMilliseconds"] = String(budget)
        metadata["modelLatencyForBudgetMilliseconds"] = String(measuredLatency)

        if enforceLatencyCeiling,
           !allowLatencyBypass,
           measuredLatency > budget {
            let suppression = DisplayScoreSuppression(
                reason: .tooSlowToDisplay,
                trace: scoredDecision.trace
            )
            metadata = suppression.metadata
            metadata["completionConfidenceBucket"] = confidence.bucket.rawValue
            metadata["completionConfidenceScore"] = String(confidence.score)
            metadata["completionConfidenceReasons"] = confidence.reasons.joined(separator: ",")
            metadata["modelDisplayLatencyBudgetMilliseconds"] = String(budget)
            metadata["modelLatencyForBudgetMilliseconds"] = String(measuredLatency)
            return GoodAndFastEnoughDecision(
                decision: .suppress(suppression),
                confidence: confidence,
                latencyBudgetMilliseconds: budget,
                measuredLatencyMilliseconds: measuredLatency,
                metadata: metadata
            )
        }

        let suppressLowConfidence = !confidence.canDisplay
            && (!allowLatencyBypass || !confidence.reasons.contains("late-context-validation-required"))
        if suppressLowConfidence {
            let suppression = DisplayScoreSuppression(
                reason: .lowConfidence,
                trace: scoredDecision.trace
            )
            metadata = suppression.metadata
            metadata["completionConfidenceBucket"] = confidence.bucket.rawValue
            metadata["completionConfidenceScore"] = String(confidence.score)
            metadata["completionConfidenceReasons"] = confidence.reasons.joined(separator: ",")
            metadata["modelDisplayLatencyBudgetMilliseconds"] = String(budget)
            metadata["modelLatencyForBudgetMilliseconds"] = String(measuredLatency)
            return GoodAndFastEnoughDecision(
                decision: .suppress(suppression),
                confidence: confidence,
                latencyBudgetMilliseconds: budget,
                measuredLatencyMilliseconds: measuredLatency,
                metadata: metadata
            )
        }

        return GoodAndFastEnoughDecision(
            decision: scoredDecision,
            confidence: confidence,
            latencyBudgetMilliseconds: budget,
            measuredLatencyMilliseconds: measuredLatency,
            metadata: metadata
        )
    }

    public func fallbackDecision(
        supportStatus: CompatibilitySupportStatus,
        isEnabled: Bool,
        fieldKind: AXFieldKind? = nil,
        allowsLowConfidencePlacement: Bool? = nil,
        hasCurrentApp: Bool = true
    ) -> CommandFallbackDecision {
        commandFallbackPolicy.decision(
            supportStatus: supportStatus,
            isEnabled: isEnabled,
            fieldKind: fieldKind,
            allowsLowConfidencePlacement: allowsLowConfidencePlacement,
            hasCurrentApp: hasCurrentApp
        )
    }
}
