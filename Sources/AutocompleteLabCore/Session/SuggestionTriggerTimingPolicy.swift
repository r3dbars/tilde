import Foundation

/// Shared timing surface for trigger cadence, scheduling floors, and result
/// latency checks. The trigger policy still carries profile-specific cadence;
/// this type keeps the timing behavior from being reassembled in app plumbing.
public struct SuggestionTriggerTimingPolicy: Equatable, Sendable {
    public let requestSchedulingPolicy: SuggestionRequestSchedulingPolicy

    public init(
        requestSchedulingPolicy: SuggestionRequestSchedulingPolicy = SuggestionRequestSchedulingPolicy()
    ) {
        self.requestSchedulingPolicy = requestSchedulingPolicy
    }

    public func decision(
        using triggerPolicy: SuggestionTriggerPolicy,
        previousTextBeforeCursor: String?,
        currentTextBeforeCursor: String,
        lineStartBehavior: SuggestionLineStartBehavior = .plain,
        behaviorProfileID: AutocompleteBehaviorProfileID? = nil,
        requestMode: CompletionRequestMode? = nil
    ) -> SuggestionTriggerDecision {
        triggerPolicy.decision(
            previousTextBeforeCursor: previousTextBeforeCursor,
            currentTextBeforeCursor: currentTextBeforeCursor,
            lineStartBehavior: lineStartBehavior,
            behaviorProfileID: behaviorProfileID,
            requestMode: requestMode
        )
    }

    public func schedule(
        policyDelayMilliseconds: Int,
        timingLane: SuggestionTimingLane,
        requestMode: CompletionRequestMode,
        renderMode: SuggestionRenderMode
    ) -> SuggestionRequestSchedule {
        requestSchedulingPolicy.schedule(
            policyDelayMilliseconds: policyDelayMilliseconds,
            timingLane: timingLane,
            requestMode: requestMode,
            renderMode: renderMode
        )
    }

    public func shouldSuppressResult(
        latencyMilliseconds: Int,
        schedule: SuggestionRequestSchedule
    ) -> Bool {
        requestSchedulingPolicy.shouldSuppressResult(
            latencyMilliseconds: latencyMilliseconds,
            schedule: schedule
        )
    }
}
