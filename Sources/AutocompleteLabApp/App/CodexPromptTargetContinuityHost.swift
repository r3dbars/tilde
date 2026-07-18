import AutocompleteLabCore
import Foundation

/// Owns the live Codex prompt-continuity state used by the suggestion pipeline.
///
/// The policy remains a pure value type. This host only keeps the short-lived anchor
/// and AX-cooldown preservation state that used to be scattered through AppDelegate,
/// and exposes the decisions needed by polling and presentation. Keeping this state
/// together gives the transient-AX repair work a stable seam before it is extended.
@MainActor
final class CodexPromptTargetContinuityHost {
    let targetPolicy = CodexPromptTargetContinuityPolicy()
    let presentationRefreshRetryPolicy = CodexPromptPresentationRefreshRetryPolicy()
    let presentationPreparationPolicy = CodexPromptPresentationPreparationPolicy()

    private(set) var trustedAnchor: CodexPromptTargetContinuityAnchor?
    private(set) var axCooldownPreservation: CodexPromptAXCooldownPreservation?

    func rememberAnchor(
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        context: FocusedTextContext
    ) {
        trustedAnchor = targetPolicy.anchor(
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: context
        )
    }

    func reset() {
        trustedAnchor = nil
        axCooldownPreservation = nil
    }

    func clearCooldownPreservation() {
        axCooldownPreservation = nil
    }

    func canDeferInvalidation(
        app: RunningApplicationInfo,
        promptBlockReason: String,
        currentFieldIdentity: FocusedFieldIdentity?,
        currentSnapshot: FocusedTextSnapshot?,
        observedContext: FocusedTextContext,
        hasActiveSuggestionWork: Bool
    ) -> Bool {
        guard hasActiveSuggestionWork else {
            return false
        }

        return targetPolicy.canDeferInvalidation(
            appBundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            promptBlockReason: promptBlockReason,
            currentFieldIdentity: currentFieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: trustedAnchor,
            observedContext: observedContext
        )
    }

    func beginAXCooldownPreservation(
        app: RunningApplicationInfo,
        currentFieldIdentity: FocusedFieldIdentity?,
        currentSnapshot: FocusedTextSnapshot?,
        observedContext: FocusedTextContext,
        hasActiveSuggestionWork: Bool,
        cooldownMilliseconds: Int
    ) -> Bool {
        let shouldPreserve = targetPolicy.canBeginAXCooldownPreservation(
            appBundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            currentFieldIdentity: currentFieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: trustedAnchor,
            observedContext: observedContext,
            hasActiveSuggestionWork: hasActiveSuggestionWork
        )
        axCooldownPreservation = shouldPreserve
            ? targetPolicy.axCooldownPreservation(
                trustedAnchor: trustedAnchor,
                cooldownMilliseconds: cooldownMilliseconds
            )
            : nil
        return shouldPreserve
    }

    func canPreserveDuringAXCooldown(
        app: RunningApplicationInfo,
        currentFieldIdentity: FocusedFieldIdentity?,
        currentSnapshot: FocusedTextSnapshot?,
        hasActiveSuggestionWork: Bool
    ) -> Bool {
        targetPolicy.canPreserveDuringAXCooldown(
            appBundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            currentFieldIdentity: currentFieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: trustedAnchor,
            preservation: axCooldownPreservation,
            hasActiveSuggestionWork: hasActiveSuggestionWork
        )
    }

    func remainingAXCooldownMilliseconds() -> Int {
        targetPolicy.remainingAXCooldownMilliseconds(
            preservation: axCooldownPreservation
        )
    }

    func presentationRefreshResolution(
        app: RunningApplicationInfo,
        promptBlockReason: String,
        currentFieldIdentity: FocusedFieldIdentity?,
        currentSnapshot: FocusedTextSnapshot?,
        observedContext: FocusedTextContext,
        trustedContext: FocusedTextContext
    ) -> CodexPromptPresentationRefreshResolution {
        targetPolicy.presentationRefreshResolution(
            appBundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            promptBlockReason: promptBlockReason,
            currentFieldIdentity: currentFieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: trustedAnchor,
            observedContext: observedContext,
            trustedContext: trustedContext
        )
    }
}
