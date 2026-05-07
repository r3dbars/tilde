import AutocompleteLabCore

struct FocusedTextSuggestionUnchangedPlan: Equatable {
    let decisionText: String
}

struct FocusedTextSuggestionBlockPlan: Equatable {
    let snapshot: FocusedTextSnapshot
    let decisionText: String
    let metadata: [String: String]
    let hideReason: String?
}

struct FocusedTextPresentationSuppressionPlan: Equatable {
    let snapshot: FocusedTextSnapshot
    let decisionText: String
    let requestMode: CompletionRequestMode
    let renderMode: SuggestionRenderMode
    let reason: SuggestionPresentationSuppressionReason
}

struct FocusedTextCadenceWaitPlan: Equatable {
    let snapshot: FocusedTextSnapshot
    let decisionText: String
    let shouldRepositionVisibleSuggestion: Bool
    let shouldRecordTriggerSkipped: Bool
}

struct FocusedTextSuggestionRequestPlan: Equatable {
    let snapshot: FocusedTextSnapshot
    let requestMode: CompletionRequestMode
    let renderMode: SuggestionRenderMode
    let delayMilliseconds: Int
}

enum FocusedTextSuggestionPlan: Equatable {
    case unchanged(FocusedTextSuggestionUnchangedPlan)
    case blocked(FocusedTextSuggestionBlockPlan)
    case presentationSuppressed(FocusedTextPresentationSuppressionPlan)
    case cadenceWait(FocusedTextCadenceWaitPlan)
    case request(FocusedTextSuggestionRequestPlan)
}

struct FocusedTextSuggestionPlanner: Equatable {
    var activationPolicy: CompletionActivationPolicy
    var triggerPolicy: SuggestionTriggerPolicy
    var presentationPolicy: SuggestionPresentationPolicy

    init(
        activationPolicy: CompletionActivationPolicy,
        triggerPolicy: SuggestionTriggerPolicy,
        presentationPolicy: SuggestionPresentationPolicy
    ) {
        self.activationPolicy = activationPolicy
        self.triggerPolicy = triggerPolicy
        self.presentationPolicy = presentationPolicy
    }

    func plan(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        lastTextSnapshot: FocusedTextSnapshot?,
        hasVisibleSuggestion: Bool,
        runtimeReport: RuntimeReadinessReport,
        isFieldSuppressed: Bool,
        lastRequestedTextBeforeCursor: String?,
        effectiveRenderMode: (SuggestionRenderMode) -> SuggestionRenderMode
    ) -> FocusedTextSuggestionPlan {
        let snapshot = FocusedTextSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )

        guard snapshot != lastTextSnapshot else {
            return .unchanged(FocusedTextSuggestionUnchangedPlan(
                decisionText: hasVisibleSuggestion
                    ? "Shown: tracking current field"
                    : "Ready: waiting for text change"
            ))
        }

        guard profile.canPresentSuggestions else {
            return .blocked(FocusedTextSuggestionBlockPlan(
                snapshot: snapshot,
                decisionText: "Blocked: profile diagnostics only",
                metadata: ["reason": "profile-diagnostics-only"],
                hideReason: nil
            ))
        }

        guard runtimeReport.allowsSuggestions else {
            return .blocked(FocusedTextSuggestionBlockPlan(
                snapshot: snapshot,
                decisionText: "Blocked: runtime \(runtimeReport.stage.rawValue)",
                metadata: [
                    "reason": "runtime-not-ready",
                    "readinessStage": runtimeReport.stage.rawValue
                ],
                hideReason: nil
            ))
        }

        let activationDecision = activationPolicy.decision(
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            isSecure: context.isSecure,
            selectedTextLength: context.selectedTextLength,
            isFieldSuppressed: isFieldSuppressed
        )

        guard activationDecision.canSuggest else {
            let reason = activationDecision.blockReasonDescription
            return .blocked(FocusedTextSuggestionBlockPlan(
                snapshot: snapshot,
                decisionText: "Blocked: \(reason)",
                metadata: ["reason": reason],
                hideReason: "activation-\(reason)"
            ))
        }

        let capabilities = SuggestionPresentationCapabilities(
            supportsInlineSuggestions: context.capabilities.supportsInlineSuggestions,
            hasElementRect: context.elementRect != nil,
            hasWindowRect: context.windowRect != nil,
            hasCaretRect: context.caretRect != nil
        )
        guard let baseRenderMode = presentationPolicy.baseRenderMode(
            for: profile,
            capabilities: capabilities
        ) else {
            return .blocked(FocusedTextSuggestionBlockPlan(
                snapshot: snapshot,
                decisionText: "Blocked: missing inline capabilities",
                metadata: ["reason": "missing-inline-capabilities"],
                hideReason: nil
            ))
        }

        let renderMode = effectiveRenderMode(baseRenderMode)
        let requestMode = activationDecision.requestMode ?? .phraseContinuation
        if let suppressionReason = presentationPolicy.suppressionReason(
            profile: profile,
            renderMode: renderMode,
            capabilities: capabilities
        ) {
            return .presentationSuppressed(FocusedTextPresentationSuppressionPlan(
                snapshot: snapshot,
                decisionText: "Blocked: detached suggestion disabled",
                requestMode: requestMode,
                renderMode: renderMode,
                reason: suppressionReason
            ))
        }

        let triggerDecision = triggerPolicy.decision(
            previousTextBeforeCursor: lastRequestedTextBeforeCursor,
            currentTextBeforeCursor: context.textBeforeCursor
        )

        guard case let .request(delayMilliseconds) = triggerDecision else {
            return .cadenceWait(FocusedTextCadenceWaitPlan(
                snapshot: snapshot,
                decisionText: hasVisibleSuggestion
                    ? "Shown: waiting for cadence"
                    : "Waiting: cadence policy",
                shouldRepositionVisibleSuggestion: hasVisibleSuggestion,
                shouldRecordTriggerSkipped: !hasVisibleSuggestion
            ))
        }

        return .request(FocusedTextSuggestionRequestPlan(
            snapshot: snapshot,
            requestMode: requestMode,
            renderMode: renderMode,
            delayMilliseconds: delayMilliseconds
        ))
    }
}

private extension CompletionActivationDecision {
    var blockReasonDescription: String {
        switch self {
        case .allow:
            "allowed"
        case let .block(reason):
            reason.rawValue
        }
    }
}
