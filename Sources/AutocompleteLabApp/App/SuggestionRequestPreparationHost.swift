import AutocompleteLabCore
import Foundation

@MainActor
struct SuggestionRequestPreparationHostDependencies {
    let suggestionOrchestrator: SuggestionOrchestrator
    let acceptedTextStyleSketch: (AcceptedTextStyleMemoryKey) -> AcceptedTextStyleSketch?
    let personalizationCoordinator: PersonalizationCoordinator
    let isPersonalCaptureEnabled: () -> Bool
    let maxVisibleWords: (CompletionRequestMode, CompatibilityProfile) -> Int
    let suggestionTuning: () -> SuggestionTuning
    let triggerTiming: SuggestionTriggerTimingPolicy
}

struct SuggestionRequestPreparation: Sendable {
    let orchestration: SuggestionOrchestration
    let requestSchedule: SuggestionRequestSchedule
    let requestMetadata: [String: String]
}

/// Owns request assembly and the initial streaming-state/trace transition.
/// Fast fallback selection and presentation stay in AppDelegate until their own seams
/// are extracted, so this host only moves the shared request setup boundary.
@MainActor
final class SuggestionRequestPreparationHost {
    private let dependencies: SuggestionRequestPreparationHostDependencies

    init(dependencies: SuggestionRequestPreparationHostDependencies) {
        self.dependencies = dependencies
    }

    func prepare(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        fieldClassification: AXFieldClassification,
        renderMode: SuggestionRenderMode,
        delayMilliseconds: Int,
        timingLane: SuggestionTimingLane,
        requestMode: CompletionRequestMode,
        typingBurstDecision: TypingBurstDecision,
        visiblePageContext: VisiblePageContext?,
        triggerReason: String
    ) -> SuggestionRequestPreparation {
        let acceptedTextStyleKey = dependencies.suggestionOrchestrator.acceptedTextStyleKey(
            appBundleIdentifier: appBundleIdentifier,
            fieldKind: fieldClassification.kind,
            textBeforeCursor: context.textBeforeCursor
        )
        let acceptedTextStyleSketch = dependencies.acceptedTextStyleSketch(acceptedTextStyleKey)
        let personalization = dependencies.personalizationCoordinator.selection(
            isEnabled: dependencies.isPersonalCaptureEnabled(),
            context: context,
            appBundleIdentifier: appBundleIdentifier,
            fieldClassification: fieldClassification,
            requestMode: requestMode
        )
        let orchestration = dependencies.suggestionOrchestrator.beginRequest(SuggestionRequestInput(
            context: context,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity,
            fieldClassification: fieldClassification,
            acceptedTextStyleSketch: acceptedTextStyleSketch,
            personalContext: personalization.context,
            personalWritingMemory: personalization.memory,
            visiblePageContext: visiblePageContext,
            maxVisibleWords: dependencies.maxVisibleWords(requestMode, profile),
            requestMode: requestMode,
            suggestionTuning: dependencies.suggestionTuning()
        ))
        let requestSchedule = dependencies.triggerTiming.schedule(
            policyDelayMilliseconds: delayMilliseconds,
            timingLane: timingLane,
            requestMode: orchestration.request.mode,
            renderMode: renderMode
        )
        let requestMetadata = orchestration.requestMetadata
            .merging(timingLane.traceMetadata) { current, _ in current }
        let typingBurstMetadata: [String: String] = typingBurstDecision == .idle
            ? [:]
            : typingBurstDecision.traceMetadata

        dependencies.suggestionOrchestrator.startStreamingPresentation(
            suggestionID: orchestration.suggestionID
        )
        RawAutocompleteTraceLog.shared.record(
            type: .suggestionRequested,
            suggestionID: orchestration.suggestionID,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: orchestration.fieldIdentityDescription,
            requestMode: orchestration.request.mode.rawValue,
            triggerReason: triggerReason,
            textBeforeCursor: orchestration.request.textBeforeCursor,
            textAfterCursor: orchestration.request.textAfterCursor,
            metadata: [
                "renderMode": renderMode.rawValue
            ]
            .merging(typingBurstMetadata) { current, _ in current }
            .merging(requestSchedule.traceMetadata) { current, _ in current }
            .merging(requestMetadata) { current, _ in current }
        )

        return SuggestionRequestPreparation(
            orchestration: orchestration,
            requestSchedule: requestSchedule,
            requestMetadata: requestMetadata
        )
    }
}
