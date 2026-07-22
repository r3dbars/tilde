import AutocompleteLabCore

@MainActor
struct SuggestionSchedulingHostDependencies {
    let cancelPrefixCooldownRetry: () -> Void
    let cancelPendingSuggestionTask: (String) -> Void
    let setLastRequestedTextBeforeCursor: (String?) -> Void
    let suggestionRequestPreparationHost: SuggestionRequestPreparationHost
    let suggestionOrchestrator: SuggestionOrchestrator
    let runtimeProofOptions: RuntimeProofOptions
    let activeAppProofBundleIdentifiers: Set<String>
    let recentWordMemoryWords: (String) -> [String]
    let suggestionSession: SuggestionSessionHost
    let currentSuggestionID: () -> String?
    let acceptedAndKeptSignal: (CompletionRequest, AXFieldClassification, CompatibilityProfile) -> AcceptedAndKeptLearningSignal
    let acceptedAndKeptLearning: () -> AcceptedAndKeptLearningStore
    let shouldAskModelForWordCompletionFallback: (VisiblePageContext?) -> Bool
    let shouldUsePredictiveWordFallback: (CompatibilityProfile, VisiblePageContext?) -> Bool
    let shouldUsePredictivePhraseFallback: (CompatibilityProfile, AutocompleteBehaviorProfileID?, VisiblePageContext?) -> Bool
    let triggerPolicy: (CompatibilityProfile) -> SuggestionTriggerPolicy
    let suggestionTypingBurstSuppressionHost: SuggestionTypingBurstSuppressionHost
    let suggestionRequestExecutionHost: SuggestionRequestExecutionHost
    let suggestionIdleRetryState: SuggestionIdleRetryStateHost
    let recordSuggestionEvent: (String, FocusedTextContext, CompatibilityProfile, [String: String]) -> Void
    let recordAnnoyanceSignal: (AnnoyanceSignal, AnnoyanceContext?, String, String, [String: String]) -> Void
    let annoyanceContext: (String, FocusedFieldIdentity?, CompletionRequestMode?, AXFieldKind) -> AnnoyanceContext
    let setSuggestionDecision: (String) -> Void
    let repositionVisibleSuggestion: (FocusedTextContext, CompatibilityProfile) -> Void
    let hideSuggestion: () -> Void
    let presentSuggestion: (
        CompletionSuggestion,
        String,
        CompletionRequest,
        FocusedTextContext,
        CompatibilityProfile,
        FocusedFieldIdentity,
        SuggestionRenderMode,
        Int,
        String,
        SuggestionRequestTicket?,
        [String: String],
        Bool
    ) -> Void
}

/// Owns request scheduling, local fast-path selection, proof-mode gates, and model handoff.
/// Core timing and quality policies remain injected; native presentation remains a callback.
@MainActor
final class SuggestionSchedulingHost {
    private let dependencies: SuggestionSchedulingHostDependencies

    init(dependencies: SuggestionSchedulingHostDependencies) {
        self.dependencies = dependencies
    }

    private var suggestionRequestPreparationHost: SuggestionRequestPreparationHost {
        dependencies.suggestionRequestPreparationHost
    }

    private var suggestionOrchestrator: SuggestionOrchestrator {
        dependencies.suggestionOrchestrator
    }

    private var runtimeProofOptions: RuntimeProofOptions {
        dependencies.runtimeProofOptions
    }

    private var activeAppProofBundleIdentifiers: Set<String> {
        dependencies.activeAppProofBundleIdentifiers
    }

    private var suggestionSession: SuggestionSessionHost {
        dependencies.suggestionSession
    }

    private var acceptedAndKeptLearning: AcceptedAndKeptLearningStore {
        dependencies.acceptedAndKeptLearning()
    }

    private var suggestionTypingBurstSuppressionHost: SuggestionTypingBurstSuppressionHost {
        dependencies.suggestionTypingBurstSuppressionHost
    }

    private var suggestionRequestExecutionHost: SuggestionRequestExecutionHost {
        dependencies.suggestionRequestExecutionHost
    }

    private var suggestionIdleRetryState: SuggestionIdleRetryStateHost {
        dependencies.suggestionIdleRetryState
    }

    private func cancelPrefixCooldownRetry() {
        dependencies.cancelPrefixCooldownRetry()
    }

    private func cancelPendingSuggestionTask(reason: String) {
        dependencies.cancelPendingSuggestionTask(reason)
    }

    private func recordSuggestionEvent(
        _ event: String,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        metadata: [String: String] = [:]
    ) {
        dependencies.recordSuggestionEvent(event, context, profile, metadata)
    }

    private func recordAnnoyanceSignal(
        _ signal: AnnoyanceSignal,
        context: AnnoyanceContext?,
        suggestionID: String = "",
        reason: String,
        metadata: [String: String] = [:]
    ) {
        dependencies.recordAnnoyanceSignal(signal, context, suggestionID, reason, metadata)
    }

    private func annoyanceContext(
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity?,
        requestMode: CompletionRequestMode?,
        fieldKind: AXFieldKind = .unknown
    ) -> AnnoyanceContext {
        dependencies.annoyanceContext(appBundleIdentifier, fieldIdentity, requestMode, fieldKind)
    }

    private func setSuggestionDecision(_ decision: String) {
        dependencies.setSuggestionDecision(decision)
    }

    private func repositionVisibleSuggestion(
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) {
        dependencies.repositionVisibleSuggestion(context, profile)
    }

    private func hideSuggestion() {
        dependencies.hideSuggestion()
    }

    private func acceptedAndKeptSignal(
        request: CompletionRequest,
        fieldClassification: AXFieldClassification,
        profile: CompatibilityProfile
    ) -> AcceptedAndKeptLearningSignal {
        dependencies.acceptedAndKeptSignal(request, fieldClassification, profile)
    }

    private func shouldAskModelForWordCompletionFallback(
        visiblePageContext: VisiblePageContext?
    ) -> Bool {
        dependencies.shouldAskModelForWordCompletionFallback(visiblePageContext)
    }

    private func shouldUsePredictiveWordFallback(
        profile: CompatibilityProfile,
        visiblePageContext: VisiblePageContext?
    ) -> Bool {
        dependencies.shouldUsePredictiveWordFallback(profile, visiblePageContext)
    }

    private func shouldUsePredictivePhraseFallback(
        profile: CompatibilityProfile,
        behaviorProfileID: AutocompleteBehaviorProfileID?,
        visiblePageContext: VisiblePageContext?
    ) -> Bool {
        dependencies.shouldUsePredictivePhraseFallback(profile, behaviorProfileID, visiblePageContext)
    }

    private func triggerPolicy(for profile: CompatibilityProfile) -> SuggestionTriggerPolicy {
        dependencies.triggerPolicy(profile)
    }

    private func presentSuggestion(
        _ suggestion: CompletionSuggestion,
        suggestionID: String,
        request: CompletionRequest,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        renderMode: SuggestionRenderMode,
        latencyMilliseconds: Int,
        triggerReason: String,
        requestTicket: SuggestionRequestTicket? = nil,
        candidateSelectionMetadata: [String: String] = [:],
        refreshBeforePresenting: Bool = true
    ) {
        dependencies.presentSuggestion(
            suggestion,
            suggestionID,
            request,
            context,
            profile,
            fieldIdentity,
            renderMode,
            latencyMilliseconds,
            triggerReason,
            requestTicket,
            candidateSelectionMetadata,
            refreshBeforePresenting
        )
    }

    func scheduleSuggestion(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        fieldClassification: AXFieldClassification,
        renderMode: SuggestionRenderMode,
        delayMilliseconds: Int,
        timingLane: SuggestionTimingLane,
        requestMode: CompletionRequestMode,
        typingBurstDecision: TypingBurstDecision = .idle,
        visiblePageContext: VisiblePageContext?,
        triggerReason: String = "poll"
    ) {
        cancelPrefixCooldownRetry()
        cancelPendingSuggestionTask(reason: "new-request")
        dependencies.setLastRequestedTextBeforeCursor(context.textBeforeCursor)

        let preparation = suggestionRequestPreparationHost.prepare(
            context: context,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity,
            fieldClassification: fieldClassification,
            renderMode: renderMode,
            delayMilliseconds: delayMilliseconds,
            timingLane: timingLane,
            requestMode: requestMode,
            typingBurstDecision: typingBurstDecision,
            visiblePageContext: visiblePageContext,
            triggerReason: triggerReason
        )
        let orchestration = preparation.orchestration
        let request = orchestration.request
        let suggestionID = orchestration.suggestionID
        let fieldIdentityDescription = orchestration.fieldIdentityDescription
        let requestMetadata = preparation.requestMetadata
        let requestTicket = orchestration.ticket
        let requestStartedAt = orchestration.startedAt
        let requestSchedule = preparation.requestSchedule
        let typingBurstMetadata: [String: String] = typingBurstDecision == .idle
            ? [:]
            : typingBurstDecision.traceMetadata

        let disablesFastWordCompletionForProof = runtimeProofOptions.disablesFastWordCompletion(
            appBundleIdentifier: appBundleIdentifier,
            activeProofBundleIdentifiers: activeAppProofBundleIdentifiers
        )
        let disablesWordCompletionForProof = runtimeProofOptions.disablesWordCompletion(
            appBundleIdentifier: appBundleIdentifier,
            activeProofBundleIdentifiers: activeAppProofBundleIdentifiers
        )
        let disablesPhraseContinuationForProof = runtimeProofOptions.disablesPhraseContinuation(
            appBundleIdentifier: appBundleIdentifier,
            activeProofBundleIdentifiers: activeAppProofBundleIdentifiers
        )
        let disablesFastPhraseFallbackForProof = runtimeProofOptions.disablesFastPhraseFallback(
            appBundleIdentifier: appBundleIdentifier,
            activeProofBundleIdentifiers: activeAppProofBundleIdentifiers
        )

        if requestMode == .wordCompletion,
           disablesWordCompletionForProof {
            DiagnosticsLog.shared.record(
                "word-completion-disabled",
                metadata: [
                    "app": appBundleIdentifier,
                    "reason": RuntimeProofOptions.disableWordCompletionEnvironmentKey
                ]
            )
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: suggestionID,
                appBundleIdentifier: appBundleIdentifier,
                fieldIdentity: fieldIdentityDescription,
                requestMode: request.mode.rawValue,
                triggerReason: "proof-word-completion-disabled",
                textBeforeCursor: request.textBeforeCursor,
                textAfterCursor: request.textAfterCursor,
                reason: "proof-word-completion-disabled",
                metadata: [
                    "renderMode": renderMode.rawValue,
                    "proofDisableReason": RuntimeProofOptions.disableWordCompletionEnvironmentKey
                ]
                .merging(requestMetadata) { current, _ in current }
            )
            recordSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                metadata: [
                    "reason": "proof-word-completion-disabled"
                ]
            )
            setSuggestionDecision("Blocked: proof word completion disabled")
            hideSuggestion()
            return
        }

        if requestMode == .wordCompletion,
           !disablesFastWordCompletionForProof {
            let candidateWords = dependencies.recentWordMemoryWords(appBundleIdentifier)
                + (visiblePageContext?.completionCandidateWords ?? [])
            let allowPredictiveFallback = shouldUsePredictiveWordFallback(
                profile: profile,
                visiblePageContext: visiblePageContext
            )
            let fastSelection = suggestionOrchestrator.fastWordSelection(
                for: context.textBeforeCursor,
                recentWords: candidateWords,
                allowPredictiveFallback: allowPredictiveFallback
            )
            let fastSelectionMetadata = fastSelection.traceMetadata
                .merging(timingLane.traceMetadata) { current, _ in current }
            if let fastSuggestion = fastSelection.suggestion {
                guard !suggestionOrchestrator.shouldSuppressRepetition(
                    fastSuggestion.visibleText,
                    mode: request.mode,
                    scope: appBundleIdentifier
                ) else {
                    RawAutocompleteTraceLog.shared.record(
                        type: .suggestionSuppressed,
                        suggestionID: suggestionID,
                        appBundleIdentifier: appBundleIdentifier,
                        fieldIdentity: fieldIdentityDescription,
                        requestMode: request.mode.rawValue,
                        triggerReason: "fast-word-completion",
                        textBeforeCursor: request.textBeforeCursor,
                        textAfterCursor: request.textAfterCursor,
                        cleanedVisibleText: fastSuggestion.visibleText,
                        displayedText: fastSuggestion.visibleText,
                        latencyMilliseconds: 0,
                        reason: "repeated-miss",
                        metadata: [
                            "renderMode": renderMode.rawValue
                        ]
                        .merging(fastSelectionMetadata) { current, _ in current }
                        .merging(requestMetadata) { current, _ in current }
                    )
                    recordSuggestionEvent(
                        "suggestion-blocked",
                        context: context,
                        profile: profile,
                        metadata: [
                            "reason": "repeated-miss",
                            "triggerReason": "fast-word-completion"
                        ]
                    )
                    recordAnnoyanceSignal(
                        .repeatedRejection,
                        context: annoyanceContext(
                            appBundleIdentifier: appBundleIdentifier,
                            fieldIdentity: fieldIdentity,
                            requestMode: request.mode,
                            fieldKind: fieldClassification.kind
                        ),
                        suggestionID: suggestionID,
                        reason: "repeated-miss"
                    )
                    setSuggestionDecision(SuggestionStatusText.notShown(reason: "repeated-miss"))
                    hideSuggestion()
                    return
                }

                presentSuggestion(
                    fastSuggestion,
                    suggestionID: suggestionID,
                    request: request,
                    context: context,
                    profile: profile,
                    fieldIdentity: fieldIdentity,
                    renderMode: renderMode,
                    latencyMilliseconds: 0,
                    triggerReason: "fast-word-completion",
                    requestTicket: requestTicket,
                    candidateSelectionMetadata: fastSelectionMetadata,
                    refreshBeforePresenting: false
                )
                return
            }

            if timingLane == .instantWord {
                let reason = "instant-word-no-local-candidate"
                RawAutocompleteTraceLog.shared.record(
                    type: .suggestionSuppressed,
                    suggestionID: suggestionID,
                    appBundleIdentifier: appBundleIdentifier,
                    fieldIdentity: fieldIdentityDescription,
                    requestMode: request.mode.rawValue,
                    triggerReason: "fast-word-completion",
                    textBeforeCursor: request.textBeforeCursor,
                    textAfterCursor: request.textAfterCursor,
                    reason: reason,
                    metadata: [
                        "renderMode": renderMode.rawValue
                    ]
                    .merging(timingLane.traceMetadata) { current, _ in current }
                    .merging(fastSelectionMetadata) { current, _ in current }
                    .merging(requestMetadata) { current, _ in current }
                )
                if suggestionSession.hasVisibleSuggestion {
                    setSuggestionDecision("Shown: no instant word replacement")
                    repositionVisibleSuggestion(context: context, profile: profile)
                    return
                }

                setSuggestionDecision("Waiting: no instant word match")
                hideSuggestion()
                return
            }

            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: suggestionID,
                appBundleIdentifier: appBundleIdentifier,
                fieldIdentity: fieldIdentityDescription,
                requestMode: request.mode.rawValue,
                triggerReason: "fast-word-completion",
                textBeforeCursor: request.textBeforeCursor,
                textAfterCursor: request.textAfterCursor,
                reason: "no-fast-word-candidate",
                metadata: [
                    "renderMode": renderMode.rawValue
                ]
                .merging(fastSelectionMetadata) { current, _ in current }
                .merging(requestMetadata) { current, _ in current }
            )
            if shouldAskModelForWordCompletionFallback(visiblePageContext: visiblePageContext) {
                setSuggestionDecision("Queued: model word completion")
            } else if suggestionSession.hasVisibleSuggestion {
                setSuggestionDecision("Shown: no fast word replacement")
                repositionVisibleSuggestion(context: context, profile: profile)
                return
            } else {
                setSuggestionDecision(SuggestionStatusText.notShown(reason: "no-fast-word-candidate"))
                hideSuggestion()
                return
            }
        } else if requestMode == .wordCompletion,
                  disablesFastWordCompletionForProof {
            DiagnosticsLog.shared.record(
                "fast-word-completion-disabled",
                metadata: [
                    "app": appBundleIdentifier,
                    "reason": RuntimeProofOptions.disableFastWordCompletionEnvironmentKey
                ]
            )
            setSuggestionDecision("Queued: proof model word completion")
        }

        if requestMode == .phraseContinuation,
           disablesPhraseContinuationForProof {
            DiagnosticsLog.shared.record(
                "phrase-continuation-disabled",
                metadata: [
                    "app": appBundleIdentifier,
                    "reason": RuntimeProofOptions.disablePhraseContinuationEnvironmentKey
                ]
            )
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: suggestionID,
                appBundleIdentifier: appBundleIdentifier,
                fieldIdentity: fieldIdentityDescription,
                requestMode: request.mode.rawValue,
                triggerReason: "proof-phrase-continuation-disabled",
                textBeforeCursor: request.textBeforeCursor,
                textAfterCursor: request.textAfterCursor,
                reason: "proof-phrase-continuation-disabled",
                metadata: [
                    "renderMode": renderMode.rawValue,
                    "proofDisableReason": RuntimeProofOptions.disablePhraseContinuationEnvironmentKey
                ]
                .merging(requestMetadata) { current, _ in current }
            )
            recordSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                metadata: [
                    "reason": "proof-phrase-continuation-disabled"
                ]
            )
            setSuggestionDecision("Blocked: proof phrase continuation disabled")
            hideSuggestion()
            return
        }

        var fastPhraseFallbackMetadata: [String: String] = [:]
        var didPresentFastPhraseFallback = false
        if requestMode == .phraseContinuation,
           !disablesFastPhraseFallbackForProof {
            let allowsPredictivePhraseFallback = shouldUsePredictivePhraseFallback(
                profile: profile,
                behaviorProfileID: request.behaviorProfileID,
                visiblePageContext: visiblePageContext
            )
            let fastSelection = suggestionOrchestrator.fastPhraseSelection(
                for: context.textBeforeCursor,
                docLocalContextTexts: orchestration.docLocalContextTexts,
                behaviorProfileID: request.behaviorProfileID,
                maxVisibleWords: request.maxVisibleWords,
                allowPredictiveFallback: allowsPredictivePhraseFallback,
                allowPromptAppPrediction: false
            )
            let fastSelectionMetadata = fastSelection.traceMetadata
                .merging(timingLane.traceMetadata) { current, _ in current }
            if let fastSuggestion = fastSelection.suggestion {
                guard !suggestionOrchestrator.shouldSuppressRepetition(
                    fastSuggestion.visibleText,
                    mode: request.mode,
                    scope: appBundleIdentifier
                ) else {
                    RawAutocompleteTraceLog.shared.record(
                        type: .suggestionSuppressed,
                        suggestionID: suggestionID,
                        appBundleIdentifier: appBundleIdentifier,
                        fieldIdentity: fieldIdentityDescription,
                        requestMode: request.mode.rawValue,
                        triggerReason: "canned-bridge",
                        textBeforeCursor: request.textBeforeCursor,
                        textAfterCursor: request.textAfterCursor,
                        cleanedVisibleText: fastSuggestion.visibleText,
                        displayedText: fastSuggestion.visibleText,
                        latencyMilliseconds: 0,
                        reason: "repeated-miss",
                        metadata: [
                            "renderMode": renderMode.rawValue
                        ]
                        .merging(fastSelectionMetadata) { current, _ in current }
                        .merging(requestMetadata) { current, _ in current }
                    )
                    recordSuggestionEvent(
                        "suggestion-blocked",
                        context: context,
                        profile: profile,
                        metadata: [
                            "reason": "repeated-miss",
                            "triggerReason": "canned-bridge"
                        ]
                    )
                    recordAnnoyanceSignal(
                        .repeatedRejection,
                        context: annoyanceContext(
                            appBundleIdentifier: appBundleIdentifier,
                            fieldIdentity: fieldIdentity,
                            requestMode: request.mode,
                            fieldKind: fieldClassification.kind
                        ),
                        suggestionID: suggestionID,
                        reason: "repeated-miss"
                    )
                    setSuggestionDecision(SuggestionStatusText.notShown(reason: "repeated-miss"))
                    hideSuggestion()
                    return
                }

                let acceptedAndKeptSignal = acceptedAndKeptSignal(
                    request: request,
                    fieldClassification: fieldClassification,
                    profile: profile
                )
                let learningDecision = suggestionOrchestrator.fastPhraseFallbackLearningDecision(
                    acceptedAndKeptSignal: acceptedAndKeptSignal,
                    probabilityThreshold: acceptedAndKeptLearning.probabilityThreshold(for: request.mode)
                )
                let fastPresentationMetadata = fastSelectionMetadata
                    .merging(learningDecision.metadata) { current, _ in current }
                if learningDecision.shouldSuppress {
                    let reason = learningDecision.reason ?? "fast-phrase-learning-restraint"
                    fastPhraseFallbackMetadata = [
                        "fastPhraseFallbackChecked": "true",
                        "fastPhraseFallbackOutcome": reason
                    ]
                    .merging(fastPresentationMetadata) { current, _ in current }
                    RawAutocompleteTraceLog.shared.record(
                        type: .suggestionSuppressed,
                        suggestionID: suggestionID,
                        appBundleIdentifier: appBundleIdentifier,
                        fieldIdentity: fieldIdentityDescription,
                        requestMode: request.mode.rawValue,
                        triggerReason: "canned-bridge",
                        textBeforeCursor: request.textBeforeCursor,
                        textAfterCursor: request.textAfterCursor,
                        latencyMilliseconds: 0,
                        reason: reason,
                        metadata: [
                            "renderMode": renderMode.rawValue
                        ]
                        .merging(fastPresentationMetadata) { current, _ in current }
                        .merging(requestMetadata) { current, _ in current }
                    )
                    recordSuggestionEvent(
                        "suggestion-blocked",
                        context: context,
                        profile: profile,
                        metadata: [
                            "reason": reason,
                            "triggerReason": "canned-bridge"
                        ]
                        .merging(learningDecision.metadata) { current, _ in current }
                    )
                    setSuggestionDecision(SuggestionStatusText.notShown(reason: reason))
                } else {
                    presentSuggestion(
                        fastSuggestion,
                        suggestionID: suggestionID,
                        request: request,
                        context: context,
                        profile: profile,
                        fieldIdentity: fieldIdentity,
                        renderMode: renderMode,
                        latencyMilliseconds: 0,
                        triggerReason: "canned-bridge",
                        requestTicket: requestTicket,
                        candidateSelectionMetadata: fastPresentationMetadata,
                        refreshBeforePresenting: false
                    )
                    didPresentFastPhraseFallback = suggestionSession.hasVisibleSuggestion
                        && dependencies.currentSuggestionID() == suggestionID
                    fastPhraseFallbackMetadata = [
                        "fastPhraseFallbackChecked": "true",
                        "fastPhraseFallbackOutcome": didPresentFastPhraseFallback
                            ? "shown-then-model"
                            : "presentation-blocked-model-only",
                        "fastPhraseFallbackVisibleWords": String(fastSuggestion.visibleWordCount)
                    ]
                    .merging(fastPresentationMetadata) { current, _ in current }
                    if didPresentFastPhraseFallback {
                        setSuggestionDecision("Shown: instant phrase; refining with model")
                    }
                }
            }

            let fastPhraseFallbackOutcome = fastSelection.suppressionReason ?? "no-suggestion"
            if fastPhraseFallbackMetadata.isEmpty {
                fastPhraseFallbackMetadata = [
                    "fastPhraseFallbackChecked": "true",
                    "fastPhraseFallbackOutcome": fastPhraseFallbackOutcome
                ]
                .merging(fastSelectionMetadata) { current, _ in current }
                setSuggestionDecision("Queued: model phrase after instant \(fastPhraseFallbackOutcome)")
            }
        } else if requestMode == .phraseContinuation,
                  disablesFastPhraseFallbackForProof {
            DiagnosticsLog.shared.record(
                "fast-phrase-fallback-disabled",
                metadata: [
                    "app": appBundleIdentifier,
                    "reason": RuntimeProofOptions.disableFastPhraseFallbackEnvironmentKey
                ]
            )
            setSuggestionDecision("Queued: proof model phrase continuation")
        }

        if typingBurstDecision.shouldSuppress(requestMode: requestMode) {
            suggestionTypingBurstSuppressionHost.handle(
                input: SuggestionTypingBurstSuppressionInput(
                    suggestionID: suggestionID,
                    appBundleIdentifier: appBundleIdentifier,
                    fieldIdentity: fieldIdentity,
                    requestMode: request.mode,
                    requestTextBeforeCursor: request.textBeforeCursor,
                    requestTextAfterCursor: request.textAfterCursor,
                    fieldIdentityDescription: fieldIdentityDescription,
                    context: context,
                    profile: profile,
                    fieldClassification: fieldClassification,
                    renderMode: renderMode,
                    typingBurstMetadata: typingBurstMetadata,
                    fastPhraseFallbackMetadata: fastPhraseFallbackMetadata,
                    requestMetadata: requestMetadata,
                    settleDelayMilliseconds: triggerPolicy(for: profile).pauseDelayMilliseconds
                ),
                didPresentFastPhraseFallback: didPresentFastPhraseFallback
            )
            return
        }

        recordSuggestionEvent(
            "suggestion-request-scheduled",
            context: context,
            profile: profile,
            metadata: [
                "requestMode": request.mode.rawValue,
                "triggerReason": triggerReason,
                "traceID": String(suggestionID.prefix(8)),
                "suggestionID": suggestionID
            ]
            .merging(typingBurstMetadata) { current, _ in current }
            .merging(fastPhraseFallbackMetadata) { current, _ in current }
            .merging(requestSchedule.traceMetadata) { current, _ in current }
            .merging(requestMetadata) { current, _ in current }
        )
        suggestionIdleRetryState.cancel()
        suggestionRequestExecutionHost.schedule(
            input: SuggestionModelResultInput(
                suggestionID: suggestionID,
                request: request,
                context: context,
                profile: profile,
                appBundleIdentifier: appBundleIdentifier,
                fieldIdentity: fieldIdentity,
                fieldClassification: fieldClassification,
                fieldIdentityDescription: fieldIdentityDescription,
                renderMode: renderMode,
                requestMetadata: requestMetadata,
                requestSchedule: requestSchedule,
                requestTicket: requestTicket,
                requestStartedAt: requestStartedAt
            )
        )
    }
}
