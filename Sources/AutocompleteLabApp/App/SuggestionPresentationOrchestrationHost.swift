import AutocompleteLabCore
import Foundation

@MainActor
struct SuggestionPresentationRefreshRetryInput {
    let suggestion: CompletionSuggestion
    let suggestionID: String
    let request: CompletionRequest
    let context: FocusedTextContext
    let profile: CompatibilityProfile
    let fieldIdentity: FocusedFieldIdentity
    let renderMode: SuggestionRenderMode
    let latencyMilliseconds: Int
    let triggerReason: String
    let requestTicket: SuggestionRequestTicket?
    let candidateSelectionMetadata: [String: String]
    let scheduledDelayMilliseconds: Int
    let retry: CodexPromptPresentationRefreshRetry
}

@MainActor
struct SuggestionPresentationAXCooldownInput {
    let suggestion: CompletionSuggestion
    let suggestionID: String
    let request: CompletionRequest
    let context: FocusedTextContext
    let profile: CompatibilityProfile
    let fieldIdentity: FocusedFieldIdentity
    let renderMode: SuggestionRenderMode
    let latencyMilliseconds: Int
    let triggerReason: String
    let requestTicket: SuggestionRequestTicket?
    let candidateSelectionMetadata: [String: String]
    let scheduledDelayMilliseconds: Int
    let presentationRefreshAttempt: Int
    let delayMilliseconds: Int
}

@MainActor
struct SuggestionPresentationOrchestrationHostDependencies {
    let codexPromptTargetContinuityHost: CodexPromptTargetContinuityHost
    let suggestionOrchestrator: SuggestionOrchestrator
    let suggestionSession: SuggestionSessionHost
    let currentSuggestionState: CurrentSuggestionStateHost
    let currentFieldIdentity: () -> FocusedFieldIdentity?
    let lastTextSnapshot: () -> FocusedTextSnapshot?
    let displayScorePolicy: DisplayScorePolicy
    let suggestionTuning: () -> SuggestionTuning
    let rawEvaluationModeEnabled: () -> Bool
    let suggestionReplacementVisibilityPolicy: SuggestionReplacementVisibilityPolicy
    let maximumPreservedSuggestionDisplaySuppressionAgeMilliseconds: Int
    let suggestionPresentationPreparationHost: SuggestionPresentationPreparationHost
    let suggestionPresentationSuppressionTraceHost: SuggestionPresentationSuppressionTraceHost
    let suggestionPresentationPlacementHost: SuggestionPresentationPlacementHost
    let suggestionPresentationDeliveryHost: SuggestionPresentationDeliveryHost
    let suggestionPresentationCommitHost: SuggestionPresentationCommitHost
    let codexPromptAXCooldownPresentationDelayMilliseconds: (CompatibilityProfile, FocusedFieldIdentity) -> Int
    let scheduleCodexPromptPresentationRefreshRetry: (SuggestionPresentationRefreshRetryInput) -> Void
    let scheduleCodexPromptPresentationAfterAXCooldown: (SuggestionPresentationAXCooldownInput) -> Void
    let refreshedPresentationContext: (CompletionRequest, FocusedTextContext, CompatibilityProfile, FocusedFieldIdentity) -> (context: FocusedTextContext?, reason: String?)
    let traceGeometryMetadata: (FocusedTextContext, SuggestionRenderMode) -> [String: String]
    let traceRequestMetadata: (CompletionRequest, FocusedTextContext) -> [String: String]
    let traceRequestMetadataForField: (CompletionRequest, AXFieldClassification) -> [String: String]
    let fieldClassification: (FocusedTextContext) -> AXFieldClassification
    let effectiveSuggestionFieldClassification: (FocusedTextContext, CompatibilityProfile, AXFieldClassification) -> AXFieldClassification
    let acceptedAndKeptSignal: (CompletionRequest, AXFieldClassification, CompatibilityProfile) -> AcceptedAndKeptLearningSignal
    let currentSuggestionAgeMilliseconds: () -> Int?
    let setSuggestionDecision: (String) -> Void
    let hideSuggestion: (String, [String: String]) -> Void
    let showFieldStatusIndicator: (FieldStatusIndicatorState, FocusedTextContext) -> Void
    let repositionVisibleSuggestion: (FocusedTextContext, CompatibilityProfile) -> Void
    let updateKeyboardEventTapSnapshot: () -> Void
    let setLastCompatibilityLearningTrustContext: (CompatibilityLearningVisualTrustContext) -> Void
    let cancelKeyboardEventTapIdleStop: () -> Void
}

/// Owns the policy-and-host orchestration between a model result and native suggestion delivery.
@MainActor
final class SuggestionPresentationOrchestrationHost {
    private let dependencies: SuggestionPresentationOrchestrationHostDependencies

    init(dependencies: SuggestionPresentationOrchestrationHostDependencies) {
        self.dependencies = dependencies
    }

    private var codexPromptTargetContinuityHost: CodexPromptTargetContinuityHost {
        dependencies.codexPromptTargetContinuityHost
    }

    private var suggestionOrchestrator: SuggestionOrchestrator {
        dependencies.suggestionOrchestrator
    }

    private var suggestionSession: SuggestionSessionHost {
        dependencies.suggestionSession
    }

    private var currentSuggestionState: CurrentSuggestionStateHost {
        dependencies.currentSuggestionState
    }

    private var currentFieldIdentity: FocusedFieldIdentity? {
        dependencies.currentFieldIdentity()
    }

    private var lastTextSnapshot: FocusedTextSnapshot? {
        dependencies.lastTextSnapshot()
    }

    private var displayScorePolicy: DisplayScorePolicy {
        dependencies.displayScorePolicy
    }

    private var suggestionTuning: SuggestionTuning {
        dependencies.suggestionTuning()
    }

    private var rawEvaluationModeEnabled: Bool {
        dependencies.rawEvaluationModeEnabled()
    }

    private var suggestionReplacementVisibilityPolicy: SuggestionReplacementVisibilityPolicy {
        dependencies.suggestionReplacementVisibilityPolicy
    }

    private var maximumPreservedSuggestionDisplaySuppressionAgeMilliseconds: Int {
        dependencies.maximumPreservedSuggestionDisplaySuppressionAgeMilliseconds
    }

    private var suggestionPresentationPreparationHost: SuggestionPresentationPreparationHost {
        dependencies.suggestionPresentationPreparationHost
    }

    private var suggestionPresentationSuppressionTraceHost: SuggestionPresentationSuppressionTraceHost {
        dependencies.suggestionPresentationSuppressionTraceHost
    }

    private var suggestionPresentationPlacementHost: SuggestionPresentationPlacementHost {
        dependencies.suggestionPresentationPlacementHost
    }

    private var suggestionPresentationDeliveryHost: SuggestionPresentationDeliveryHost {
        dependencies.suggestionPresentationDeliveryHost
    }

    private var suggestionPresentationCommitHost: SuggestionPresentationCommitHost {
        dependencies.suggestionPresentationCommitHost
    }

    private func setSuggestionDecision(_ decision: String) {
        dependencies.setSuggestionDecision(decision)
    }

    private func hideSuggestion(
        reason: String,
        metadata: [String: String] = [:]
    ) {
        dependencies.hideSuggestion(reason, metadata)
    }

    private func showFieldStatusIndicator(
        _ state: FieldStatusIndicatorState,
        context: FocusedTextContext
    ) {
        dependencies.showFieldStatusIndicator(state, context)
    }

    private func repositionVisibleSuggestion(
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) {
        dependencies.repositionVisibleSuggestion(context, profile)
    }

    private func updateKeyboardEventTapSnapshot() {
        dependencies.updateKeyboardEventTapSnapshot()
    }

    private func cancelKeyboardEventTapIdleStop() {
        dependencies.cancelKeyboardEventTapIdleStop()
    }

    private func traceGeometryMetadata(
        context: FocusedTextContext,
        renderMode: SuggestionRenderMode
    ) -> [String: String] {
        dependencies.traceGeometryMetadata(context, renderMode)
    }

    private func traceRequestMetadata(
        request: CompletionRequest,
        context: FocusedTextContext
    ) -> [String: String] {
        dependencies.traceRequestMetadata(request, context)
    }

    private func traceRequestMetadata(
        request: CompletionRequest,
        fieldClassification: AXFieldClassification
    ) -> [String: String] {
        dependencies.traceRequestMetadataForField(request, fieldClassification)
    }

    private func fieldClassification(for context: FocusedTextContext) -> AXFieldClassification {
        dependencies.fieldClassification(context)
    }

    private func effectiveSuggestionFieldClassificationForCurrentFrontmost(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        raw: AXFieldClassification
    ) -> AXFieldClassification {
        dependencies.effectiveSuggestionFieldClassification(context, profile, raw)
    }

    private func acceptedAndKeptSignal(
        request: CompletionRequest,
        fieldClassification: AXFieldClassification,
        profile: CompatibilityProfile
    ) -> AcceptedAndKeptLearningSignal {
        dependencies.acceptedAndKeptSignal(request, fieldClassification, profile)
    }

    private func currentSuggestionAgeMilliseconds(now: Date = Date()) -> Int? {
        dependencies.currentSuggestionAgeMilliseconds()
    }

    private func codexPromptAXCooldownPresentationDelayMilliseconds(
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity
    ) -> Int {
        dependencies.codexPromptAXCooldownPresentationDelayMilliseconds(profile, fieldIdentity)
    }

    private func refreshedPresentationContext(
        for request: CompletionRequest,
        requestContext: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity
    ) -> (context: FocusedTextContext?, reason: String?) {
        dependencies.refreshedPresentationContext(request, requestContext, profile, fieldIdentity)
    }

    private func scheduleCodexPromptPresentationRefreshRetry(
        _ suggestion: CompletionSuggestion,
        suggestionID: String,
        request: CompletionRequest,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        renderMode: SuggestionRenderMode,
        latencyMilliseconds: Int,
        triggerReason: String,
        requestTicket: SuggestionRequestTicket?,
        candidateSelectionMetadata: [String: String],
        scheduledDelayMilliseconds: Int,
        retry: CodexPromptPresentationRefreshRetry
    ) {
        dependencies.scheduleCodexPromptPresentationRefreshRetry(
            SuggestionPresentationRefreshRetryInput(
                suggestion: suggestion,
                suggestionID: suggestionID,
                request: request,
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                renderMode: renderMode,
                latencyMilliseconds: latencyMilliseconds,
                triggerReason: triggerReason,
                requestTicket: requestTicket,
                candidateSelectionMetadata: candidateSelectionMetadata,
                scheduledDelayMilliseconds: scheduledDelayMilliseconds,
                retry: retry
            )
        )
    }

    private func scheduleCodexPromptPresentationAfterAXCooldown(
        _ suggestion: CompletionSuggestion,
        suggestionID: String,
        request: CompletionRequest,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        renderMode: SuggestionRenderMode,
        latencyMilliseconds: Int,
        triggerReason: String,
        requestTicket: SuggestionRequestTicket?,
        candidateSelectionMetadata: [String: String],
        scheduledDelayMilliseconds: Int,
        presentationRefreshAttempt: Int,
        delayMilliseconds: Int
    ) {
        dependencies.scheduleCodexPromptPresentationAfterAXCooldown(
            SuggestionPresentationAXCooldownInput(
                suggestion: suggestion,
                suggestionID: suggestionID,
                request: request,
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                renderMode: renderMode,
                latencyMilliseconds: latencyMilliseconds,
                triggerReason: triggerReason,
                requestTicket: requestTicket,
                candidateSelectionMetadata: candidateSelectionMetadata,
                scheduledDelayMilliseconds: scheduledDelayMilliseconds,
                presentationRefreshAttempt: presentationRefreshAttempt,
                delayMilliseconds: delayMilliseconds
            )
        )
    }

        func presentSuggestion(
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
        refreshBeforePresenting: Bool = true,
        scheduledDelayMilliseconds: Int = 0,
        presentationRefreshAttempt: Int = 0
    ) {
        let originalContext = context
        let invalidatedByVisibleUserTyping = currentSuggestionState.invalidatedByUserKeyDown
            && currentSuggestionState.id == suggestionID
        let cooldownDelayMilliseconds = refreshBeforePresenting
            ? codexPromptAXCooldownPresentationDelayMilliseconds(
                profile: profile,
                fieldIdentity: fieldIdentity
            )
            : 0
        let refreshedContext: (context: FocusedTextContext?, reason: String?)
        switch codexPromptTargetContinuityHost.presentationPreparationPolicy.preparation(
            refreshBeforePresenting: refreshBeforePresenting,
            cooldownDelayMilliseconds: cooldownDelayMilliseconds
        ) {
        case let .deferForAXCooldown(delayMilliseconds):
            scheduleCodexPromptPresentationAfterAXCooldown(
                suggestion,
                suggestionID: suggestionID,
                request: request,
                context: originalContext,
                profile: profile,
                fieldIdentity: fieldIdentity,
                renderMode: renderMode,
                latencyMilliseconds: latencyMilliseconds,
                triggerReason: triggerReason,
                requestTicket: requestTicket,
                candidateSelectionMetadata: candidateSelectionMetadata,
                scheduledDelayMilliseconds: scheduledDelayMilliseconds,
                presentationRefreshAttempt: presentationRefreshAttempt,
                delayMilliseconds: delayMilliseconds
            )
            return
        case .refreshFocusedContext:
            refreshedContext = refreshedPresentationContext(
                for: request,
                requestContext: context,
                profile: profile,
                fieldIdentity: fieldIdentity
            )
        case .useOriginalContext:
            refreshedContext = (context: context, reason: nil)
        }
        let verifiedRefreshContext = refreshBeforePresenting ? refreshedContext.context : nil
        let freshnessFieldIdentity = verifiedRefreshContext == nil
            ? currentFieldIdentity
            : fieldIdentity
        let freshnessSnapshot = verifiedRefreshContext.map {
            FocusedTextSnapshot(
                fieldIdentity: fieldIdentity,
                textBeforeCursor: $0.textBeforeCursor,
                textAfterCursor: $0.textAfterCursor
            )
        } ?? lastTextSnapshot
        if let suppressionReason = suggestionOrchestrator.presentationSuppressionReason(
            requestTicket: requestTicket,
            request: request,
            fieldIdentity: fieldIdentity,
            currentFieldIdentity: freshnessFieldIdentity,
            currentSnapshot: freshnessSnapshot,
            invalidatedByUserTyping: invalidatedByVisibleUserTyping
        ) {
            let reason = suppressionReason.rawValue
            let metadata = traceGeometryMetadata(context: originalContext, renderMode: renderMode)
                .merging(traceRequestMetadata(request: request, context: originalContext)) { current, _ in current }
                .merging(candidateSelectionMetadata) { current, _ in current }
                .merging([
                    "presentationFreshness": "stale",
                    "presentationFreshnessReason": reason,
                    "presentationFreshnessSource": verifiedRefreshContext == nil ? "cached-snapshot" : "live-refresh"
                ]) { current, _ in current }
            setSuggestionDecision("Blocked: \(reason)")
            suggestionPresentationSuppressionTraceHost.record(
                input: SuggestionPresentationSuppressionTraceInput(
                    suggestion: suggestion,
                    suggestionID: suggestionID,
                    request: request,
                    context: originalContext,
                    profile: profile,
                    fieldIdentity: fieldIdentity,
                    latencyMilliseconds: latencyMilliseconds,
                    triggerReason: triggerReason,
                    reason: reason,
                    traceMetadata: metadata,
                    eventMetadata: ["reason": reason]
                        .merging(metadata) { current, _ in current }
                )
            )
            hideSuggestion(reason: reason)
            return
        }

        guard let context = refreshedContext.context else {
            let refreshReason = refreshedContext.reason ?? "stale-focused-context"
            if refreshReason == "transient-codex-prompt-target",
               let retry = codexPromptTargetContinuityHost.presentationRefreshRetryPolicy.next(
                after: presentationRefreshAttempt
               ) {
                scheduleCodexPromptPresentationRefreshRetry(
                    suggestion,
                    suggestionID: suggestionID,
                    request: request,
                    context: originalContext,
                    profile: profile,
                    fieldIdentity: fieldIdentity,
                    renderMode: renderMode,
                    latencyMilliseconds: latencyMilliseconds,
                    triggerReason: triggerReason,
                    requestTicket: requestTicket,
                    candidateSelectionMetadata: candidateSelectionMetadata,
                    scheduledDelayMilliseconds: scheduledDelayMilliseconds,
                    retry: retry
                )
                return
            }
            let reason = refreshReason == "transient-codex-prompt-target"
                ? "stale-prompt-target"
                : refreshReason
            let metadata = traceGeometryMetadata(context: originalContext, renderMode: renderMode)
                .merging(traceRequestMetadata(request: request, context: originalContext)) { current, _ in current }
                .merging(candidateSelectionMetadata) { current, _ in current }
            suggestionPresentationSuppressionTraceHost.record(
                input: SuggestionPresentationSuppressionTraceInput(
                    suggestion: suggestion,
                    suggestionID: suggestionID,
                    request: request,
                    context: originalContext,
                    profile: profile,
                    fieldIdentity: fieldIdentity,
                    latencyMilliseconds: latencyMilliseconds,
                    triggerReason: triggerReason,
                    reason: reason,
                    traceMetadata: metadata,
                    eventMetadata: ["reason": reason]
                        .merging(metadata) { current, _ in current }
                )
            )
            setSuggestionDecision(SuggestionStatusText.notShown(reason: reason))
            hideSuggestion(reason: reason)
            return
        }

        let preparationResult = suggestionPresentationPreparationHost.prepare(
            input: SuggestionPresentationPreparationInput(
                suggestion: suggestion,
                request: request,
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                renderMode: renderMode,
                latencyMilliseconds: latencyMilliseconds,
                screenshotTracingEnabled: RawAutocompleteTraceLog.shared.screenshotTracingEnabled
            )
        )
        let suggestion: CompletionSuggestion
        let visualTrustContext: CompatibilityLearningVisualTrustContext
        let learningAdjustment: CompatibilityLearningAdjustment
        let placementPlan: PlacementHealthPlan
        switch preparationResult {
        case let .invalid(reason):
            hideSuggestion(reason: "late-result-\(reason.rawValue)")
            return
        case .typedThroughVisiblePrefix:
            hideSuggestion(reason: "typed-through-visible-prefix")
            return
        case let .ready(prepared):
            suggestion = prepared.suggestion
            visualTrustContext = prepared.visualTrustContext
            learningAdjustment = prepared.learningAdjustment
            placementPlan = prepared.placementPlan
        }

        guard case let .present(placement) = placementPlan else {
            let placementSuppression = suggestionOrchestrator.placementSuppressionResolution(
                for: placementPlan,
                requestedRenderMode: learningAdjustment.effectiveRenderMode,
                profile: profile,
                fieldKind: request.fieldKind
            )
            let suppression = placementSuppression.suppression
            let commandFallbackMetadata = placementSuppression.metadata
            let placementMetadata = traceGeometryMetadata(
                context: context,
                renderMode: learningAdjustment.effectiveRenderMode
            )
                .merging(traceRequestMetadata(request: request, context: context)) { current, _ in current }
                .merging(learningAdjustment.metadata) { current, _ in current }
                .merging(commandFallbackMetadata) { current, _ in current }
                .merging(suppression.metadata) { current, _ in current }
            suggestionPresentationPlacementHost.suppress(
                input: SuggestionPresentationPlacementSuppressionInput(
                    suggestion: suggestion,
                    suggestionID: suggestionID,
                    request: request,
                    context: context,
                    profile: profile,
                    fieldIdentity: fieldIdentity,
                    latencyMilliseconds: latencyMilliseconds,
                    triggerReason: triggerReason,
                    suppression: placementSuppression,
                    traceMetadata: placementMetadata,
                    eventMetadata: ["reason": suppression.reason.rawValue]
                        .merging(traceRequestMetadata(request: request, context: context)) { current, _ in current }
                        .merging(learningAdjustment.metadata) { current, _ in current }
                        .merging(commandFallbackMetadata) { current, _ in current }
                        .merging(suppression.metadata) { current, _ in current }
                )
            )
            return
        }

        let rawDisplayFieldClassification = fieldClassification(for: context)
        let displayFieldClassification = effectiveSuggestionFieldClassificationForCurrentFrontmost(
            context: context,
            profile: profile,
            raw: rawDisplayFieldClassification
        )
        let displayRequestMetadata = traceRequestMetadata(
            request: request,
            fieldClassification: displayFieldClassification
        )
        let acceptedAndKeptSignal = acceptedAndKeptSignal(
            request: request,
            fieldClassification: displayFieldClassification,
            profile: profile
        )
        let isInstantLocalSuggestion = triggerReason == "canned-bridge"
        let isRepeatedMiss = (isInstantLocalSuggestion || rawEvaluationModeEnabled) ? false : suggestionOrchestrator.shouldSuppressRepetition(
            suggestion.visibleText,
            mode: request.mode,
            scope: request.appBundleIdentifier ?? profile.bundleIdentifier
        )
        // A final model result is "first visible" when nothing is already on screen for the user
        // to read — no instant local phrase and no streamed partial. In that case a slow result
        // would paint cold and late, so displayScoreDecision applies a tighter latency ceiling.
        // When a suggestion is already visible, the model result is a refinement and keeps the
        // looser budget so good late refinements can still replace the instant phrase in place.
        let modelIsFirstVisibleSuggestion = triggerReason == "model-result"
            && !suggestionSession.hasVisibleSuggestion
        let orchestratedDisplayDecision = suggestionOrchestrator.displayScoreDecision(
            suggestion: suggestion,
            request: request,
            context: context,
            fieldClassification: displayFieldClassification,
            profile: profile,
            fieldIdentity: fieldIdentity,
            triggerReason: triggerReason,
            latencyMilliseconds: latencyMilliseconds,
            acceptedAndKeptSignal: acceptedAndKeptSignal,
            isRepeatedMiss: isRepeatedMiss,
            displayScorePolicy: displayScorePolicy,
            suggestionTuning: suggestionTuning,
            bypassProductHeuristics: rawEvaluationModeEnabled,
            modelIsFirstVisibleSuggestion: modelIsFirstVisibleSuggestion,
            scheduledDelayMilliseconds: scheduledDelayMilliseconds
        )
        let displayScoreDecision = orchestratedDisplayDecision.decision
        let displayScoreMetadata = orchestratedDisplayDecision.metadata
        let displayScoreTrace = displayScoreDecision.trace
        guard displayScoreDecision.shouldDisplay else {
            let reason = displayScoreMetadata["displayScoreSuppressionReason"] ?? "display-score"
            let displaySuppressionReason = DisplayScoreSuppressionReason(rawValue: reason)
            let shouldKeepStreamedSuggestion: Bool
            if displaySuppressionReason == .tooSlowToDisplay,
               let requestTicket {
                shouldKeepStreamedSuggestion = suggestionOrchestrator.shouldKeepVisibleStreamingSuggestionAfterEmptyFinal(
                    suggestionID: suggestionID,
                    currentSuggestionID: currentSuggestionState.id,
                    ticket: requestTicket,
                    fieldIdentity: fieldIdentity,
                    currentFieldIdentity: currentFieldIdentity,
                    hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion
                )
            } else {
                shouldKeepStreamedSuggestion = false
            }
            let visibleSuggestionAction = suggestionReplacementVisibilityPolicy.action(
                forDisplaySuppressionReason: displaySuppressionReason,
                hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
                currentSuggestionInvalidatedByUserTyping: currentSuggestionState.invalidatedByUserKeyDown,
                sameFieldAsCurrentSuggestion: currentSuggestionState.appBundleIdentifier == (request.appBundleIdentifier ?? profile.bundleIdentifier)
                    && currentSuggestionState.fieldIdentity == fieldIdentity,
                currentSuggestionAgeMilliseconds: currentSuggestionAgeMilliseconds(),
                maximumPreservedAgeMilliseconds: maximumPreservedSuggestionDisplaySuppressionAgeMilliseconds
            )
            let shouldKeepCurrentVisibleSuggestion = shouldKeepStreamedSuggestion
                || visibleSuggestionAction == .keepCurrentVisible
            var lateSuggestionMetadata: [String: String] = [:]
            if shouldKeepStreamedSuggestion {
                lateSuggestionMetadata["keptVisibleStreamingSuggestion"] = "true"
            }
            if visibleSuggestionAction == .keepCurrentVisible {
                lateSuggestionMetadata["keptVisibleSuggestionAfterLateSuppression"] = "true"
                lateSuggestionMetadata["lateSuppressionPreservedAgeMilliseconds"] =
                    currentSuggestionAgeMilliseconds().map(String.init) ?? "unknown"
            }
            setSuggestionDecision(SuggestionStatusText.notShown(reason: reason))
            let suppressionMetadata = traceGeometryMetadata(context: context, renderMode: placement.renderMode)
                .merging(traceRequestMetadata(request: request, context: context)) { current, _ in current }
                .merging(learningAdjustment.metadata) { current, _ in current }
                .merging(placement.metadata) { current, _ in current }
                .merging(candidateSelectionMetadata) { current, _ in current }
                .merging(displayScoreMetadata) { current, _ in current }
                .merging(lateSuggestionMetadata) { current, _ in current }
            suggestionPresentationSuppressionTraceHost.record(
                input: SuggestionPresentationSuppressionTraceInput(
                    suggestion: suggestion,
                    suggestionID: suggestionID,
                    request: request,
                    context: context,
                    profile: profile,
                    fieldIdentity: fieldIdentity,
                    latencyMilliseconds: latencyMilliseconds,
                    triggerReason: triggerReason,
                    reason: reason,
                    traceMetadata: suppressionMetadata,
                    eventMetadata: ["reason": reason]
                        .merging(traceRequestMetadata(request: request, context: context)) { current, _ in current }
                        .merging(learningAdjustment.metadata) { current, _ in current }
                        .merging(placement.metadata) { current, _ in current }
                        .merging(candidateSelectionMetadata) { current, _ in current }
                        .merging(displayScoreMetadata) { current, _ in current }
                        .merging(lateSuggestionMetadata) { current, _ in current }
                )
            )
            if shouldKeepCurrentVisibleSuggestion {
                setSuggestionDecision(
                    shouldKeepStreamedSuggestion
                        ? "Shown: kept streamed suggestion"
                        : "Shown: kept visible suggestion after late \(reason)"
                )
                showFieldStatusIndicator(.shown, context: context)
                repositionVisibleSuggestion(context: context, profile: profile)
                updateKeyboardEventTapSnapshot()
                return
            }
            hideSuggestion(reason: reason)
            return
        }

        let replacementDecision = rawEvaluationModeEnabled
            ? SuggestionReplacementDecision(shouldPresent: true)
            : suggestionOrchestrator.replacementDecision(
                currentVisibleText: suggestionSession.visibleSuggestion?.visibleText,
                proposedVisibleText: suggestion.visibleText,
                currentSuggestionID: currentSuggestionState.id,
                proposedSuggestionID: suggestionID,
                currentPresentedAt: currentSuggestionState.presentedAt,
                currentScore: currentSuggestionState.displayScoreFinal,
                proposedScore: displayScoreTrace.score.finalScore,
                currentSuggestionInvalidatedByUserTyping: currentSuggestionState.invalidatedByUserKeyDown
            )
        let replacementMetadata = replacementDecision.metadata
        let replacementVisibilityAction = suggestionReplacementVisibilityPolicy.action(
            for: replacementDecision,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
            currentSuggestionInvalidatedByUserTyping: currentSuggestionState.invalidatedByUserKeyDown
        )
        guard replacementVisibilityAction == .presentProposed else {
            let reason = replacementDecision.reason?.rawValue ?? "replacement-gate"
            setSuggestionDecision("Kept current suggestion: \(reason)")
            let suppressionMetadata = traceGeometryMetadata(context: context, renderMode: placement.renderMode)
                .merging(traceRequestMetadata(request: request, context: context)) { current, _ in current }
                .merging(learningAdjustment.metadata) { current, _ in current }
                .merging(placement.metadata) { current, _ in current }
                .merging(candidateSelectionMetadata) { current, _ in current }
                .merging(displayScoreMetadata) { current, _ in current }
                .merging(replacementMetadata) { current, _ in current }
            suggestionPresentationSuppressionTraceHost.record(
                input: SuggestionPresentationSuppressionTraceInput(
                    suggestion: suggestion,
                    suggestionID: suggestionID,
                    request: request,
                    context: context,
                    profile: profile,
                    fieldIdentity: fieldIdentity,
                    latencyMilliseconds: latencyMilliseconds,
                    triggerReason: triggerReason,
                    reason: reason,
                    traceMetadata: suppressionMetadata,
                    eventMetadata: ["reason": reason]
                        .merging(traceRequestMetadata(request: request, context: context)) { current, _ in current }
                        .merging(learningAdjustment.metadata) { current, _ in current }
                        .merging(placement.metadata) { current, _ in current }
                        .merging(candidateSelectionMetadata) { current, _ in current }
                        .merging(displayScoreMetadata) { current, _ in current }
                        .merging(replacementMetadata) { current, _ in current }
                )
            )

            switch replacementVisibilityAction {
            case .presentProposed:
                break
            case .keepCurrentVisible:
                showFieldStatusIndicator(.shown, context: context)
                repositionVisibleSuggestion(context: context, profile: profile)
                updateKeyboardEventTapSnapshot()
            case .hide:
                hideSuggestion(reason: reason)
            }
            return
        }

        dependencies.setLastCompatibilityLearningTrustContext(visualTrustContext)
        cancelKeyboardEventTapIdleStop()
        let presentationDeliveryRequest = SuggestionPresentationDeliveryRequest(
            suggestion: suggestion,
            suggestionID: suggestionID,
            completionRequest: request,
            context: context,
            profile: profile,
            fieldIdentity: fieldIdentity,
            placement: placement,
            latencyMilliseconds: latencyMilliseconds,
            requestMetadata: displayRequestMetadata,
            geometryMetadata: traceGeometryMetadata(context: context, renderMode: placement.renderMode),
            learningMetadata: learningAdjustment.metadata,
            candidateSelectionMetadata: candidateSelectionMetadata,
            displayScoreMetadata: displayScoreMetadata,
            replacementMetadata: replacementMetadata
        )
        guard let delivery = suggestionPresentationDeliveryHost.deliver(
            input: SuggestionPresentationDeliveryHostInput(
                presentationDeliveryRequest: presentationDeliveryRequest,
                triggerReason: triggerReason,
                traceGeometryMetadata: traceGeometryMetadata(
                    context: context,
                    renderMode: placement.renderMode
                ),
                traceRequestMetadata: traceRequestMetadata(request: request, context: context)
            )
        ) else {
            return
        }
        let panelRect = delivery.panelRect
        let deliveredPlacement = delivery.placement

        let presentationCommitInput = SuggestionPresentationCommitInput(
            suggestion: suggestion,
            suggestionID: suggestionID,
            request: request,
            context: context,
            profile: profile,
            fieldIdentity: fieldIdentity,
            rawDisplayFieldClassification: rawDisplayFieldClassification,
            displayFieldClassification: displayFieldClassification,
            latencyMilliseconds: latencyMilliseconds,
            triggerReason: triggerReason,
            deliveredPlacement: deliveredPlacement,
            panelRect: panelRect,
            presentationDeliveryRequest: presentationDeliveryRequest,
            visualTrustContext: visualTrustContext,
            learningAdjustment: learningAdjustment,
            displayScoreFinal: displayScoreTrace.score.finalScore
        )
        _ = suggestionPresentationCommitHost.commit(input: presentationCommitInput)
        return

    }
}
