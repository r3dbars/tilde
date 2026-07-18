import Foundation

/// The five behavior seams shared by the suggestion session.
///
/// The underlying policies remain individually testable while callers get one
/// dependency that describes the session-level contract: control, safety activation,
/// trigger timing, annoyance/backoff, and acceptance guarding.
public struct SuggestionSafetyActivationPolicy: Equatable, Sendable {
    public let sensitiveTextFieldPolicy: SensitiveTextFieldPolicy
    public let proofActivationModePolicy: ProofActivationModePolicy

    public init(
        sensitiveTextFieldPolicy: SensitiveTextFieldPolicy = SensitiveTextFieldPolicy(),
        proofActivationModePolicy: ProofActivationModePolicy = ProofActivationModePolicy()
    ) {
        self.sensitiveTextFieldPolicy = sensitiveTextFieldPolicy
        self.proofActivationModePolicy = proofActivationModePolicy
    }

    public func activationDecision(
        using activationPolicy: CompletionActivationPolicy,
        textBeforeCursor: String,
        textAfterCursor: String,
        isSecure: Bool,
        selectedTextLength: Int = 0,
        isFieldSuppressed: Bool,
        fieldKind: AXFieldKind = .multilineCompose,
        allowsUnknownFieldKind: Bool = false,
        allowsTrustedProofSensitiveContent: Bool = false
    ) -> CompletionActivationDecision {
        activationPolicy.decision(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor,
            isSecure: isSecure,
            selectedTextLength: selectedTextLength,
            isFieldSuppressed: isFieldSuppressed,
            fieldKind: fieldKind,
            allowsUnknownFieldKind: allowsUnknownFieldKind,
            allowsTrustedProofSensitiveContent: allowsTrustedProofSensitiveContent
        )
    }

    public func adjustedProofDecision(
        original: CompletionActivationDecision,
        wordFallback: CompletionActivationDecision,
        disablesPhraseContinuation: Bool,
        disablesWordCompletion: Bool
    ) -> CompletionActivationDecision {
        proofActivationModePolicy.adjustedDecision(
            original: original,
            wordFallback: wordFallback,
            disablesPhraseContinuation: disablesPhraseContinuation,
            disablesWordCompletion: disablesWordCompletion
        )
    }
}

/// Single dependency surface for the five session behaviors. This is intentionally
/// a value bundle: it adds no new state machine and therefore cannot create a second
/// cooldown, trigger, or acceptance path.
public struct SuggestionSessionBehaviors: Equatable, Sendable {
    public let control: SuggestionControlPolicy
    public let safetyActivation: SuggestionSafetyActivationPolicy
    public let triggerTiming: SuggestionTriggerTimingPolicy
    public let annoyanceBackoff: SuggestionAnnoyanceBackoffPolicy
    public let acceptanceGuard: SuggestionAcceptanceGuard

    public init(
        control: SuggestionControlPolicy = SuggestionControlPolicy(),
        safetyActivation: SuggestionSafetyActivationPolicy = SuggestionSafetyActivationPolicy(),
        triggerTiming: SuggestionTriggerTimingPolicy = SuggestionTriggerTimingPolicy(),
        annoyanceBackoff: SuggestionAnnoyanceBackoffPolicy = SuggestionAnnoyanceBackoffPolicy(),
        acceptanceGuard: SuggestionAcceptanceGuard = SuggestionAcceptanceGuard()
    ) {
        self.control = control
        self.safetyActivation = safetyActivation
        self.triggerTiming = triggerTiming
        self.annoyanceBackoff = annoyanceBackoff
        self.acceptanceGuard = acceptanceGuard
    }
}
