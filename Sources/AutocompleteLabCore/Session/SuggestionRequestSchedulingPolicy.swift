import Foundation

public struct SuggestionRequestSchedule: Equatable, Sendable {
    public let policyDelayMilliseconds: Int
    public let scheduledDelayMilliseconds: Int
    public let resultLatencyBudgetMilliseconds: Int
    public let reason: String

    public init(
        policyDelayMilliseconds: Int,
        scheduledDelayMilliseconds: Int,
        resultLatencyBudgetMilliseconds: Int,
        reason: String
    ) {
        self.policyDelayMilliseconds = max(0, policyDelayMilliseconds)
        self.scheduledDelayMilliseconds = max(0, scheduledDelayMilliseconds)
        self.resultLatencyBudgetMilliseconds = max(1, resultLatencyBudgetMilliseconds)
        self.reason = reason
    }

    public var traceMetadata: [String: String] {
        [
            "delayMilliseconds": String(policyDelayMilliseconds),
            "policyDelayMilliseconds": String(policyDelayMilliseconds),
            "scheduledDelayMilliseconds": String(scheduledDelayMilliseconds),
            "requestSchedulingReason": reason,
            "resultLatencyBudgetMilliseconds": String(resultLatencyBudgetMilliseconds)
        ]
    }
}

public struct SuggestionRequestSchedulingPolicy: Equatable, Sendable {
    public let floatingOverlayMinimumDelayMilliseconds: Int
    public let instantWordResultBudgetMilliseconds: Int
    public let continuationResultBudgetMilliseconds: Int

    public init(
        floatingOverlayMinimumDelayMilliseconds: Int = 60,
        instantWordResultBudgetMilliseconds: Int = 450,
        continuationResultBudgetMilliseconds: Int = 750
    ) {
        self.floatingOverlayMinimumDelayMilliseconds = max(0, floatingOverlayMinimumDelayMilliseconds)
        self.instantWordResultBudgetMilliseconds = max(1, instantWordResultBudgetMilliseconds)
        self.continuationResultBudgetMilliseconds = max(1, continuationResultBudgetMilliseconds)
    }

    public func schedule(
        policyDelayMilliseconds: Int,
        timingLane: SuggestionTimingLane,
        requestMode: CompletionRequestMode,
        renderMode: SuggestionRenderMode
    ) -> SuggestionRequestSchedule {
        let boundedPolicyDelay = max(0, policyDelayMilliseconds)
        let isKeystrokeLane = timingLane == .instantWord && requestMode == .wordCompletion
        let scheduledDelay: Int
        let reason: String

        if isKeystrokeLane {
            scheduledDelay = 0
            reason = "keystroke-instant-word"
        } else if renderMode == .inlineAdjacent {
            scheduledDelay = boundedPolicyDelay
            reason = "policy-delay"
        } else {
            scheduledDelay = max(boundedPolicyDelay, floatingOverlayMinimumDelayMilliseconds)
            reason = scheduledDelay == boundedPolicyDelay ? "policy-delay" : "floating-overlay-floor"
        }

        return SuggestionRequestSchedule(
            policyDelayMilliseconds: boundedPolicyDelay,
            scheduledDelayMilliseconds: scheduledDelay,
            resultLatencyBudgetMilliseconds: isKeystrokeLane
                ? instantWordResultBudgetMilliseconds
                : continuationResultBudgetMilliseconds,
            reason: reason
        )
    }

    public func shouldSuppressResult(
        latencyMilliseconds: Int,
        schedule: SuggestionRequestSchedule
    ) -> Bool {
        latencyMilliseconds > schedule.resultLatencyBudgetMilliseconds
    }
}
