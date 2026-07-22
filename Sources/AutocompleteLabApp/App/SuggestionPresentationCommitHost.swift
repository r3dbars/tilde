import AutocompleteLabCore
import CoreGraphics
import Foundation

struct SuggestionPresentationCommitInput {
    let suggestion: CompletionSuggestion
    let suggestionID: String
    let request: CompletionRequest
    let context: FocusedTextContext
    let profile: CompatibilityProfile
    let fieldIdentity: FocusedFieldIdentity
    let rawDisplayFieldClassification: AXFieldClassification
    let displayFieldClassification: AXFieldClassification
    let latencyMilliseconds: Int
    let triggerReason: String
    let deliveredPlacement: PlacementHealthPresentation
    let panelRect: CGRect
    let presentationDeliveryRequest: SuggestionPresentationDeliveryRequest
    let visualTrustContext: CompatibilityLearningVisualTrustContext
    let learningAdjustment: CompatibilityLearningAdjustment
    let displayScoreFinal: Double
}

@MainActor
struct SuggestionPresentationCommitHostDependencies {
    let suggestionSession: SuggestionSessionHost
    let currentSuggestionState: CurrentSuggestionStateHost
    let targetFingerprint: (FocusedTextContext) -> FocusedTargetFingerprint?
    let setSuggestionDecision: (String) -> Void
    let activateKeyboardCapture: () -> Bool
    let handleKeyboardCaptureUnavailable: () -> Void
    let recordGeometry: (SuggestionPresentationCommitInput) -> Void
    let screenshotCapture: TraceScreenshotCaptureCoordinator
    let compatibilityLearningStore: CompatibilityLearningStore
    let presentationDelivery: SuggestionPresentationDelivery
    let recordPersonalCaptureEpisodePresented: (
        SuggestionPresentationCommitInput,
        TraceScreenshotCaptureResult,
        SuggestionPresentationTracePayload
    ) -> Void
    let recordSuggestionEvent: (
        SuggestionPresentationCommitInput,
        SuggestionPresentationTracePayload
    ) -> Void
    let updateKeyboardEventTapSnapshot: () -> Void
}

/// Commits a delivered suggestion into the live session and redacted trace surfaces.
/// Native policy decisions stay outside this host; this type owns only the state/telemetry
/// handoff after panel delivery has already succeeded.
@MainActor
final class SuggestionPresentationCommitHost {
    private let dependencies: SuggestionPresentationCommitHostDependencies

    init(dependencies: SuggestionPresentationCommitHostDependencies) {
        self.dependencies = dependencies
    }

    @discardableResult
    func commit(input: SuggestionPresentationCommitInput) -> Bool {
        guard let targetFingerprint = dependencies.targetFingerprint(input.context) else {
            dependencies.handleKeyboardCaptureUnavailable()
            return false
        }
        dependencies.recordGeometry(input)
        dependencies.suggestionSession.present(input.suggestion)
        dependencies.setSuggestionDecision(
            SuggestionStatusText.shown(
                mode: input.request.mode,
                triggerReason: input.triggerReason,
                latencyMilliseconds: input.latencyMilliseconds,
                metadata: input.presentationDeliveryRequest.candidateSelectionMetadata
            )
        )
        dependencies.currentSuggestionState.id = input.suggestionID
        dependencies.currentSuggestionState.appBundleIdentifier =
            input.request.appBundleIdentifier ?? input.profile.bundleIdentifier
        dependencies.currentSuggestionState.fieldIdentity = input.fieldIdentity
        dependencies.currentSuggestionState.requestMode = input.request.mode
        dependencies.currentSuggestionState.textBeforeCursor = input.request.textBeforeCursor
        let acceptanceSnapshot = SuggestionAcceptanceSnapshot(
            fieldIdentity: input.fieldIdentity,
            targetFingerprint: targetFingerprint,
            textBeforeCursor: input.context.textBeforeCursor,
            textAfterCursor: input.context.textAfterCursor,
            selectedTextLength: input.context.selectedTextLength
        )
        dependencies.currentSuggestionState.acceptanceSnapshot = acceptanceSnapshot
        let presentedAt = Date()
        dependencies.currentSuggestionState.displayedText = input.suggestion.visibleText
        dependencies.currentSuggestionState.optimisticOriginalDisplayedText = input.suggestion.visibleText
        dependencies.currentSuggestionState.optimisticTypedPrefix = ""
        dependencies.currentSuggestionState.fieldClassification = input.displayFieldClassification
        dependencies.currentSuggestionState.presentedAt = presentedAt
        dependencies.currentSuggestionState.displayScoreFinal = input.displayScoreFinal
        dependencies.currentSuggestionState.invalidatedByUserKeyDown = false

        guard dependencies.activateKeyboardCapture() else {
            dependencies.handleKeyboardCaptureUnavailable()
            return false
        }

        let screenshotCapture = dependencies.screenshotCapture.capture(
            TraceScreenshotCaptureRequest(
                rects: [
                    input.deliveredPlacement.anchorRect,
                    input.deliveredPlacement.textLineRect,
                    input.panelRect,
                    input.deliveredPlacement.clippingRect
                ].compactMap { $0 },
                expectedSignalRect: dependencies.screenshotCapture.expectedSignalRect(
                    panelRect: input.panelRect
                ),
                suggestionID: input.suggestionID,
                bundleIdentifier: input.request.appBundleIdentifier ?? input.profile.bundleIdentifier,
                triggerReason: input.triggerReason,
                appScreenshotTracingEnabled: input.learningAdjustment.shouldCaptureScreenshot,
                visualTrustContext: input.visualTrustContext
            )
        )
        dependencies.compatibilityLearningStore.recordObservation(
            for: input.profile.bundleIdentifier,
            reason: "suggestion-presented"
        )
        let presentationTracePayload = dependencies.presentationDelivery.tracePayload(
            for: input.presentationDeliveryRequest,
            placement: input.deliveredPlacement,
            panelRect: input.panelRect,
            screenshotCapture: screenshotCapture
        )
        RawAutocompleteTraceLog.shared.record(
            type: .suggestionPresented,
            suggestionID: input.suggestionID,
            appBundleIdentifier: input.request.appBundleIdentifier ?? input.profile.bundleIdentifier,
            fieldIdentity: input.fieldIdentity.traceDescription,
            requestMode: input.request.mode.rawValue,
            triggerReason: input.triggerReason,
            textBeforeCursor: input.request.textBeforeCursor,
            textAfterCursor: input.request.textAfterCursor,
            cleanedVisibleText: input.suggestion.visibleText,
            displayedText: input.suggestion.visibleText,
            latencyMilliseconds: input.latencyMilliseconds,
            screenshotPath: screenshotCapture.path,
            screenshotPathAuthorized: screenshotCapture.screenshotPathAuthorized,
            metadata: presentationTracePayload.rawTraceMetadata
        )
        dependencies.recordPersonalCaptureEpisodePresented(
            input,
            screenshotCapture,
            presentationTracePayload
        )
        dependencies.recordSuggestionEvent(input, presentationTracePayload)
        dependencies.updateKeyboardEventTapSnapshot()
        return true
    }
}
