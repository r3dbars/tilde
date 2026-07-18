import AutocompleteLabCore

struct SuggestionTriggerTimingHostInput {
    let context: FocusedTextContext
    let profile: CompatibilityProfile
    let suggestionAppBundleIdentifier: String
    let fieldIdentity: FocusedFieldIdentity
    let fieldClassification: AXFieldClassification
    let renderMode: SuggestionRenderMode
    let requestMode: CompletionRequestMode
    let previousTextBeforeCursor: String?
    let idleRetryReason: SuggestionIdleRetryReason?
    let typingBurstDecision: TypingBurstDecision
    let visiblePageContext: VisiblePageContext?
}

struct SuggestionTriggerTimingSchedule {
    let context: FocusedTextContext
    let profile: CompatibilityProfile
    let suggestionAppBundleIdentifier: String
    let fieldIdentity: FocusedFieldIdentity
    let fieldClassification: AXFieldClassification
    let renderMode: SuggestionRenderMode
    let delayMilliseconds: Int
    let timingLane: SuggestionTimingLane
    let requestMode: CompletionRequestMode
    let typingBurstDecision: TypingBurstDecision
    let visiblePageContext: VisiblePageContext?
    let triggerReason: String
}

@MainActor
struct SuggestionTriggerTimingHostDependencies {
    let triggerPolicy: (CompatibilityProfile) -> SuggestionTriggerPolicy
    let consumeManualSuggestionRequest: () -> Bool
    let hasVisibleSuggestion: () -> Bool
    let setSuggestionDecision: (String) -> Void
    let showFieldStatusIndicator: (FieldStatusIndicatorState, FocusedTextContext) -> Void
    let repositionVisibleSuggestion: (FocusedTextContext, CompatibilityProfile) -> Void
    let recordSuggestionEvent: (
        String,
        FocusedTextContext,
        CompatibilityProfile,
        [String: String]
    ) -> Void
    let hideSuggestion: () -> Void
    let scheduleSuggestion: (SuggestionTriggerTimingSchedule) -> Void
}

/// Owns trigger timing outcomes and scheduling plumbing after focused-text policy has decided.
@MainActor
final class SuggestionTriggerTimingHost {
    private let dependencies: SuggestionTriggerTimingHostDependencies

    init(dependencies: SuggestionTriggerTimingHostDependencies) {
        self.dependencies = dependencies
    }

    func handle(input: SuggestionTriggerTimingHostInput) {
        let currentLineStructure = CurrentLineStructure.from(
            textBeforeCursor: input.context.textBeforeCursor
        )
        let triggerBehaviorProfile = AutocompleteBehaviorProfileResolver().profile(
            for: AutocompleteBehaviorProfileInput(
                appBundleIdentifier: input.suggestionAppBundleIdentifier,
                fieldKind: input.fieldClassification.kind,
                currentLineStructure: currentLineStructure
            )
        )
        let triggerDecision = dependencies.triggerPolicy(input.profile).decision(
            previousTextBeforeCursor: input.previousTextBeforeCursor,
            currentTextBeforeCursor: input.context.textBeforeCursor,
            lineStartBehavior: SuggestionLineStartBehavior.behavior(
                for: triggerBehaviorProfile.id,
                currentLineStructure: currentLineStructure
            ),
            behaviorProfileID: triggerBehaviorProfile.id,
            requestMode: input.requestMode
        )
        let isManualSuggestionRequest = dependencies.consumeManualSuggestionRequest()

        let delayMilliseconds: Int
        let timingLane: SuggestionTimingLane
        if isManualSuggestionRequest {
            delayMilliseconds = 0
            timingLane = requestedTimingLane(
                from: triggerDecision,
                requestMode: input.requestMode
            )
        } else if input.idleRetryReason != nil {
            delayMilliseconds = 0
            timingLane = defaultTimingLane(for: input.requestMode)
        } else if case let .request(policyDelayMilliseconds, policyTimingLane) = triggerDecision {
            delayMilliseconds = policyDelayMilliseconds
            timingLane = policyTimingLane
        } else {
            if dependencies.hasVisibleSuggestion() {
                dependencies.setSuggestionDecision("Shown: waiting for cadence")
                dependencies.showFieldStatusIndicator(.shown, input.context)
                dependencies.repositionVisibleSuggestion(input.context, input.profile)
                return
            }

            dependencies.setSuggestionDecision("Waiting: cadence policy")
            dependencies.showFieldStatusIndicator(.waiting.withReason("typing cadence"), input.context)
            dependencies.recordSuggestionEvent(
                "suggestion-trigger-skipped",
                input.context,
                input.profile,
                ["reason": "cadence-policy"]
            )
            dependencies.hideSuggestion()
            return
        }

        dependencies.setSuggestionDecision(
            isManualSuggestionRequest
                ? "Queued: asked once \(timingLane.rawValue)"
                : "Queued: \(input.requestMode.rawValue) \(timingLane.rawValue)"
        )
        dependencies.showFieldStatusIndicator(.thinking, input.context)
        dependencies.scheduleSuggestion(
            SuggestionTriggerTimingSchedule(
                context: input.context,
                profile: input.profile,
                suggestionAppBundleIdentifier: input.suggestionAppBundleIdentifier,
                fieldIdentity: input.fieldIdentity,
                fieldClassification: input.fieldClassification,
                renderMode: input.renderMode,
                delayMilliseconds: delayMilliseconds,
                timingLane: timingLane,
                requestMode: input.requestMode,
                typingBurstDecision: input.typingBurstDecision,
                visiblePageContext: input.visiblePageContext,
                triggerReason: isManualSuggestionRequest
                    ? "manual-summon"
                    : input.idleRetryReason != nil
                        ? "idle-retry"
                        : "poll"
            )
        )
    }

    private func requestedTimingLane(
        from decision: SuggestionTriggerDecision,
        requestMode: CompletionRequestMode
    ) -> SuggestionTimingLane {
        if case let .request(_, policyTimingLane) = decision {
            return policyTimingLane
        }
        return defaultTimingLane(for: requestMode)
    }

    private func defaultTimingLane(for requestMode: CompletionRequestMode) -> SuggestionTimingLane {
        switch requestMode {
        case .wordCompletion:
            .instantWord
        case .sentenceContinuation:
            .longPauseThought
        case .phraseContinuation:
            .pausePhrase
        }
    }
}
