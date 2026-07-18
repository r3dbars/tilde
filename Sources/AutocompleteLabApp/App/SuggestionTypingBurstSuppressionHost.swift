import AutocompleteLabCore
import Foundation

@MainActor
struct SuggestionTypingBurstSuppressionHostDependencies {
    let cancelIdleRetry: () -> Void
    let setSuggestionDecision: (String) -> Void
    let showFieldStatusIndicator: (FieldStatusIndicatorState, FocusedTextContext) -> Void
    let recordSuggestionEvent: (String, FocusedTextContext, CompatibilityProfile, [String: String]) -> Void
    let recordBlockedSuggestionEvent: (
        String,
        FocusedTextContext,
        CompatibilityProfile,
        FocusedFieldIdentity,
        [String: String]
    ) -> Void
    let repositionVisibleSuggestion: (FocusedTextContext, CompatibilityProfile) -> Void
    let updateKeyboardEventTapSnapshot: () -> Void
    let noteTypingBurstSuppression: (FocusedTextSnapshot, Int, Int) -> Void
    let hideSuggestion: (String, [String: String]) -> Void
}

@MainActor
struct SuggestionTypingBurstSuppressionInput: Equatable, Sendable {
    let suggestionID: String
    let appBundleIdentifier: String
    let fieldIdentity: FocusedFieldIdentity
    let requestMode: CompletionRequestMode
    let requestTextBeforeCursor: String
    let requestTextAfterCursor: String
    let fieldIdentityDescription: String
    let context: FocusedTextContext
    let profile: CompatibilityProfile
    let fieldClassification: AXFieldClassification
    let renderMode: SuggestionRenderMode
    let typingBurstMetadata: [String: String]
    let fastPhraseFallbackMetadata: [String: String]
    let requestMetadata: [String: String]
    let settleDelayMilliseconds: Int
}

/// Owns typing-burst suppression side effects while the core TypingBurstPolicy continues to
/// decide whether suppression applies. Fast-phrase fallback stays presentation-compatible.
@MainActor
final class SuggestionTypingBurstSuppressionHost {
    private let dependencies: SuggestionTypingBurstSuppressionHostDependencies

    init(dependencies: SuggestionTypingBurstSuppressionHostDependencies) {
        self.dependencies = dependencies
    }

    func handle(
        input: SuggestionTypingBurstSuppressionInput,
        didPresentFastPhraseFallback: Bool
    ) {
        if didPresentFastPhraseFallback {
            dependencies.cancelIdleRetry()
            let metadata = baseMetadata(input: input, reason: "typing-burst-model-continuation-kept-fast-phrase")
            dependencies.setSuggestionDecision("Shown: instant phrase while typing fast")
            dependencies.showFieldStatusIndicator(.shown, input.context)
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: input.suggestionID,
                appBundleIdentifier: input.appBundleIdentifier,
                fieldIdentity: input.fieldIdentityDescription,
                requestMode: input.requestMode.rawValue,
                triggerReason: "typing-burst-policy",
                textBeforeCursor: input.requestTextBeforeCursor,
                textAfterCursor: input.requestTextAfterCursor,
                reason: "typing-burst-model-continuation-kept-fast-phrase",
                metadata: metadata
            )
            dependencies.recordSuggestionEvent(
                "suggestion-blocked",
                input.context,
                input.profile,
                metadata
            )
            dependencies.repositionVisibleSuggestion(input.context, input.profile)
            dependencies.updateKeyboardEventTapSnapshot()
            return
        }

        let metadata = baseMetadata(input: input, reason: "typing-burst-model-continuation")
        dependencies.setSuggestionDecision("Waiting: fast typing")
        dependencies.showFieldStatusIndicator(.waiting, input.context)
        RawAutocompleteTraceLog.shared.record(
            type: .suggestionSuppressed,
            suggestionID: input.suggestionID,
            appBundleIdentifier: input.appBundleIdentifier,
            fieldIdentity: input.fieldIdentityDescription,
            requestMode: input.requestMode.rawValue,
            triggerReason: "typing-burst-policy",
            textBeforeCursor: input.requestTextBeforeCursor,
            textAfterCursor: input.requestTextAfterCursor,
            reason: "typing-burst-model-continuation",
            metadata: metadata
        )
        dependencies.recordBlockedSuggestionEvent(
            "suggestion-blocked",
            input.context,
            input.profile,
            input.fieldIdentity,
            metadata
        )
        dependencies.noteTypingBurstSuppression(
            FocusedTextSnapshot(
                fieldIdentity: input.fieldIdentity,
                textBeforeCursor: input.context.textBeforeCursor,
                textAfterCursor: input.context.textAfterCursor
            ),
            Int(ProcessInfo.processInfo.systemUptime * 1_000),
            input.settleDelayMilliseconds
        )
        dependencies.hideSuggestion("typing-burst", input.typingBurstMetadata)
    }

    private func baseMetadata(
        input: SuggestionTypingBurstSuppressionInput,
        reason: String
    ) -> [String: String] {
        [
            "renderMode": input.renderMode.rawValue,
            "reason": reason
        ]
        .merging(input.fieldClassification.traceMetadata) { current, _ in current }
        .merging(input.typingBurstMetadata) { current, _ in current }
        .merging(input.fastPhraseFallbackMetadata) { current, _ in current }
        .merging(input.requestMetadata) { current, _ in current }
    }
}
