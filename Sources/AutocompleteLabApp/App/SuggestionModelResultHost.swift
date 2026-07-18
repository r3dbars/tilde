import AutocompleteLabCore
import Foundation

@MainActor
struct SuggestionModelResultHostDependencies {
    let suggestionOrchestrator: SuggestionOrchestrator
    let triggerTiming: SuggestionTriggerTimingPolicy
    let currentSuggestionID: () -> String?
    let currentFieldIdentity: () -> FocusedFieldIdentity?
    let hasVisibleSuggestion: () -> Bool
    let recordSuggestionEvent: (String, FocusedTextContext, CompatibilityProfile, [String: String]) -> Void
    let setSuggestionDecision: (String) -> Void
    let repositionVisibleSuggestion: (FocusedTextContext, CompatibilityProfile) -> Void
    let hideSuggestion: (String?) -> Void
    let annoyanceContext: (String, FocusedFieldIdentity?, CompletionRequestMode?, AXFieldKind) -> AnnoyanceContext?
    let recordAnnoyanceSignal: (AnnoyanceSignal, AnnoyanceContext?, String, String) -> Void
    let presentSuggestion: (CompletionSuggestion, SuggestionModelResultPresentation) -> Void
}

@MainActor
struct SuggestionModelResultInput: Equatable, Sendable {
    let suggestionID: String
    let request: CompletionRequest
    let context: FocusedTextContext
    let profile: CompatibilityProfile
    let appBundleIdentifier: String
    let fieldIdentity: FocusedFieldIdentity
    let fieldClassification: AXFieldClassification
    let fieldIdentityDescription: String
    let renderMode: SuggestionRenderMode
    let requestMetadata: [String: String]
    let requestSchedule: SuggestionRequestSchedule
    let requestTicket: SuggestionRequestTicket
    let requestStartedAt: Date
}

@MainActor
struct SuggestionModelResultPresentation: Equatable, Sendable {
    let suggestionID: String
    let request: CompletionRequest
    let context: FocusedTextContext
    let profile: CompatibilityProfile
    let fieldIdentity: FocusedFieldIdentity
    let renderMode: SuggestionRenderMode
    let latencyMilliseconds: Int
    let requestTicket: SuggestionRequestTicket
    let candidateSelectionMetadata: [String: String]
    let scheduledDelayMilliseconds: Int
}

/// Owns final model-result timing, empty/anchor/repetition guards, and result handoff. Native
/// presentation remains an injected callback so this host does not own AppKit state.
@MainActor
final class SuggestionModelResultHost {
    private let dependencies: SuggestionModelResultHostDependencies

    init(dependencies: SuggestionModelResultHostDependencies) {
        self.dependencies = dependencies
    }

    func handle(suggestion: CompletionSuggestion?, input: SuggestionModelResultInput) {
        let latencyMilliseconds = max(0, Int(Date().timeIntervalSince(input.requestStartedAt) * 1000))
        dependencies.suggestionOrchestrator.finishStreamingPresentation(suggestionID: input.suggestionID)
        guard dependencies.suggestionOrchestrator.allows(
            input.requestTicket,
            fieldIdentity: input.fieldIdentity,
            currentFieldIdentity: dependencies.currentFieldIdentity()
        ) else {
            return
        }

        if dependencies.triggerTiming.shouldSuppressResult(
            latencyMilliseconds: latencyMilliseconds,
            schedule: input.requestSchedule
        ) {
            let shouldKeepStreamedSuggestion = shouldKeepVisibleStreamingSuggestion(input: input)
            let metadata = input.requestMetadata
                .merging(input.requestSchedule.traceMetadata) { current, _ in current }
                .merging([
                    "resultLatencyBudgetExceeded": "true",
                    "keptVisibleStreamingSuggestion": String(shouldKeepStreamedSuggestion)
                ]) { current, _ in current }
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: input.suggestionID,
                appBundleIdentifier: input.appBundleIdentifier,
                fieldIdentity: input.fieldIdentityDescription,
                requestMode: input.request.mode.rawValue,
                triggerReason: "model-result",
                textBeforeCursor: input.request.textBeforeCursor,
                textAfterCursor: input.request.textAfterCursor,
                cleanedVisibleText: suggestion?.visibleText ?? "",
                displayedText: suggestion?.visibleText ?? "",
                latencyMilliseconds: latencyMilliseconds,
                reason: "latency-budget-exceeded",
                metadata: metadata
            )
            dependencies.recordSuggestionEvent(
                "suggestion-blocked",
                input.context,
                input.profile,
                ["reason": "latency-budget-exceeded"].merging(metadata) { current, _ in current }
            )
            if shouldKeepStreamedSuggestion {
                dependencies.setSuggestionDecision("Shown: kept streamed suggestion")
                dependencies.repositionVisibleSuggestion(input.context, input.profile)
                return
            }

            dependencies.setSuggestionDecision(SuggestionStatusText.notShown(reason: "latency-budget-exceeded"))
            dependencies.hideSuggestion("latency-budget-exceeded")
            return
        }

        let anchorRect = RenderModePlan.anchorRect(
            for: input.renderMode,
            caretRect: input.context.caretRect,
            elementRect: input.context.elementRect,
            windowRect: input.context.windowRect
        )
        guard let suggestion, !suggestion.isEmpty else {
            let shouldKeepStreamedSuggestion = shouldKeepVisibleStreamingSuggestion(input: input)
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: input.suggestionID,
                appBundleIdentifier: input.appBundleIdentifier,
                fieldIdentity: input.fieldIdentityDescription,
                requestMode: input.request.mode.rawValue,
                triggerReason: "model-result",
                textBeforeCursor: input.request.textBeforeCursor,
                textAfterCursor: input.request.textAfterCursor,
                latencyMilliseconds: latencyMilliseconds,
                reason: "empty-suggestion",
                metadata: input.requestMetadata.merging([
                    "keptVisibleStreamingSuggestion": String(shouldKeepStreamedSuggestion)
                ]) { current, _ in current }
            )
            dependencies.recordSuggestionEvent(
                "suggestion-blocked",
                input.context,
                input.profile,
                ["reason": "empty-suggestion"]
            )
            if shouldKeepStreamedSuggestion {
                dependencies.setSuggestionDecision("Shown: kept streamed suggestion")
                dependencies.repositionVisibleSuggestion(input.context, input.profile)
                return
            }

            dependencies.setSuggestionDecision(SuggestionStatusText.notShown(reason: "empty-suggestion"))
            dependencies.hideSuggestion(nil)
            return
        }

        guard anchorRect != nil else {
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: input.suggestionID,
                appBundleIdentifier: input.appBundleIdentifier,
                fieldIdentity: input.fieldIdentityDescription,
                requestMode: input.request.mode.rawValue,
                triggerReason: "model-result",
                textBeforeCursor: input.request.textBeforeCursor,
                textAfterCursor: input.request.textAfterCursor,
                cleanedVisibleText: suggestion.visibleText,
                displayedText: suggestion.visibleText,
                latencyMilliseconds: latencyMilliseconds,
                reason: "missing-anchor",
                metadata: input.requestMetadata
            )
            dependencies.recordSuggestionEvent(
                "suggestion-blocked",
                input.context,
                input.profile,
                ["reason": "missing-anchor"]
            )
            dependencies.setSuggestionDecision(SuggestionStatusText.notShown(reason: "missing-anchor"))
            dependencies.hideSuggestion(nil)
            return
        }

        let appModelResultMetadata = dependencies.suggestionOrchestrator.appModelResultCandidateSelectionMetadata(
            for: suggestion
        )
        RawAutocompleteTraceLog.shared.record(
            type: .modelResult,
            suggestionID: input.suggestionID,
            appBundleIdentifier: input.appBundleIdentifier,
            fieldIdentity: input.fieldIdentityDescription,
            requestMode: input.request.mode.rawValue,
            triggerReason: "model-result",
            textBeforeCursor: input.request.textBeforeCursor,
            textAfterCursor: input.request.textAfterCursor,
            cleanedVisibleText: suggestion.visibleText,
            displayedText: suggestion.visibleText,
            latencyMilliseconds: latencyMilliseconds,
            metadata: input.requestMetadata.merging(appModelResultMetadata) { current, _ in current }
        )
        guard !dependencies.suggestionOrchestrator.shouldSuppressRepetition(
            suggestion.visibleText,
            mode: input.request.mode,
            scope: input.appBundleIdentifier
        ) else {
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: input.suggestionID,
                appBundleIdentifier: input.appBundleIdentifier,
                fieldIdentity: input.fieldIdentityDescription,
                requestMode: input.request.mode.rawValue,
                triggerReason: "model-result",
                textBeforeCursor: input.request.textBeforeCursor,
                textAfterCursor: input.request.textAfterCursor,
                cleanedVisibleText: suggestion.visibleText,
                displayedText: suggestion.visibleText,
                latencyMilliseconds: latencyMilliseconds,
                reason: "repeated-miss",
                metadata: input.requestMetadata
            )
            dependencies.recordAnnoyanceSignal(
                .repeatedRejection,
                dependencies.annoyanceContext(
                    input.appBundleIdentifier,
                    input.fieldIdentity,
                    input.request.mode,
                    input.fieldClassification.kind
                ),
                input.suggestionID,
                "repeated-miss"
            )
            dependencies.setSuggestionDecision(SuggestionStatusText.notShown(reason: "repeated-miss"))
            dependencies.hideSuggestion(nil)
            return
        }

        dependencies.presentSuggestion(
            suggestion,
            SuggestionModelResultPresentation(
                suggestionID: input.suggestionID,
                request: input.request,
                context: input.context,
                profile: input.profile,
                fieldIdentity: input.fieldIdentity,
                renderMode: input.renderMode,
                latencyMilliseconds: latencyMilliseconds,
                requestTicket: input.requestTicket,
                candidateSelectionMetadata: appModelResultMetadata,
                scheduledDelayMilliseconds: input.requestSchedule.scheduledDelayMilliseconds
            )
        )
    }

    private func shouldKeepVisibleStreamingSuggestion(input: SuggestionModelResultInput) -> Bool {
        dependencies.suggestionOrchestrator.shouldKeepVisibleStreamingSuggestionAfterEmptyFinal(
            suggestionID: input.suggestionID,
            currentSuggestionID: dependencies.currentSuggestionID(),
            ticket: input.requestTicket,
            fieldIdentity: input.fieldIdentity,
            currentFieldIdentity: dependencies.currentFieldIdentity(),
            hasVisibleSuggestion: dependencies.hasVisibleSuggestion()
        )
    }
}
