import AutocompleteLabCore
import Foundation

struct CodexPromptTargetContinuityAnchor: Equatable {
    let fieldIdentity: FocusedFieldIdentity
    let elementIdentifier: Int
    let targetFingerprint: FocusedTargetFingerprint
    let createdAtMilliseconds: Int
}

struct CodexPromptPresentationRefreshRetry: Equatable {
    let attempt: Int
    let delayMilliseconds: Int
}

struct CodexPromptPresentationRefreshRetryPolicy {
    let maximumAttempts: Int
    let delayMilliseconds: Int

    init(maximumAttempts: Int = 3, delayMilliseconds: Int = 80) {
        self.maximumAttempts = max(0, maximumAttempts)
        self.delayMilliseconds = max(0, delayMilliseconds)
    }

    func next(after attempt: Int) -> CodexPromptPresentationRefreshRetry? {
        guard attempt >= 0, attempt < maximumAttempts else {
            return nil
        }

        return CodexPromptPresentationRefreshRetry(
            attempt: attempt + 1,
            delayMilliseconds: delayMilliseconds
        )
    }
}

struct CodexPromptTargetContinuityPolicy {
    private static let transientPromptBlockReasons: Set<String> = [
        "missing-prompt-bounds",
        "missing-prompt-fingerprint"
    ]

    func anchor(
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        context: FocusedTextContext,
        nowMilliseconds: Int = Int(ProcessInfo.processInfo.systemUptime * 1_000)
    ) -> CodexPromptTargetContinuityAnchor? {
        guard appBundleIdentifier == CodexProofFocusedTargetPolicy.bundleIdentifier,
              fieldIdentity.bundleIdentifier == appBundleIdentifier,
              context.role == "AXTextArea",
              context.selectedTextLength == 0,
              context.elementRect != nil,
              !context.isSecure else {
            return nil
        }

        return CodexPromptTargetContinuityAnchor(
            fieldIdentity: fieldIdentity,
            elementIdentifier: context.elementIdentifier,
            targetFingerprint: targetFingerprint(for: context),
            createdAtMilliseconds: nowMilliseconds
        )
    }

    func canDeferInvalidation(
        appBundleIdentifier: String,
        processIdentifier: Int32,
        promptBlockReason: String,
        currentFieldIdentity: FocusedFieldIdentity?,
        currentSnapshot: FocusedTextSnapshot?,
        trustedAnchor: CodexPromptTargetContinuityAnchor?,
        observedContext: FocusedTextContext,
        trustedContext: FocusedTextContext? = nil,
        nowMilliseconds: Int = Int(ProcessInfo.processInfo.systemUptime * 1_000),
        maximumAnchorAgeMilliseconds: Int = 1_000
    ) -> Bool {
        guard appBundleIdentifier == CodexProofFocusedTargetPolicy.bundleIdentifier,
              Self.transientPromptBlockReasons.contains(promptBlockReason),
              let currentFieldIdentity,
              let currentSnapshot,
              let trustedAnchor,
              currentFieldIdentity == trustedAnchor.fieldIdentity,
              currentSnapshot.fieldIdentity == trustedAnchor.fieldIdentity,
              trustedAnchor.fieldIdentity.bundleIdentifier == appBundleIdentifier,
              trustedAnchor.fieldIdentity.processIdentifier == processIdentifier,
              nowMilliseconds >= trustedAnchor.createdAtMilliseconds,
              nowMilliseconds - trustedAnchor.createdAtMilliseconds <= maximumAnchorAgeMilliseconds,
              Self.transientObservedRoles.contains(observedContext.role ?? ""),
              observedContext.selectedTextLength == 0,
              !observedContext.isSecure,
              observedContext.textBeforeCursor == currentSnapshot.textBeforeCursor,
              observedContext.textAfterCursor == currentSnapshot.textAfterCursor,
              trustedAnchor.targetFingerprint.surroundingTextRevision == FocusedTextRevision(
                textBeforeCursor: currentSnapshot.textBeforeCursor,
                textAfterCursor: currentSnapshot.textAfterCursor
              ),
              observationDoesNotConflict(
                trustedAnchor,
                observedContext: observedContext
              ) else {
            return false
        }

        guard let trustedContext else {
            return true
        }

        return trustedContext.role == "AXTextArea"
            && trustedContext.selectedTextLength == 0
            && trustedContext.elementRect != nil
            && !trustedContext.isSecure
            && trustedContext.textBeforeCursor == currentSnapshot.textBeforeCursor
            && trustedContext.textAfterCursor == currentSnapshot.textAfterCursor
            && trustedAnchor.targetFingerprint.matches(targetFingerprint(for: trustedContext))
    }

    private func observationDoesNotConflict(
        _ trustedAnchor: CodexPromptTargetContinuityAnchor,
        observedContext: FocusedTextContext,
        maximumGeometryDelta: Int = 4
    ) -> Bool {
        let trusted = trustedAnchor.targetFingerprint
        let observed = targetFingerprint(for: observedContext)

        if let trustedWindowIdentifier = trusted.windowIdentifier,
           let observedWindowIdentifier = observed.windowIdentifier,
           trustedWindowIdentifier != observedWindowIdentifier {
            return false
        }

        if let trustedWindowBounds = trusted.windowBounds,
           let observedWindowBounds = observed.windowBounds,
           trustedWindowBounds != observedWindowBounds {
            return false
        }

        if let trustedWindowTitle = trusted.elementFingerprint.windowTitle,
           let observedWindowTitle = observed.elementFingerprint.windowTitle,
           trustedWindowTitle != observedWindowTitle {
            return false
        }

        // AXWebArea is a transient wrapper in Codex, so its element bounds are
        // not composer bounds. The same-window and exact-text checks above keep
        // the continuity exception scoped to the already verified prompt.
        guard observedContext.role == "AXTextArea",
              let observedElementBounds = observed.elementBounds else {
            return observedContext.role != "AXTextArea"
                || observedContext.elementIdentifier == trustedAnchor.elementIdentifier
        }

        guard let trustedElementBounds = trusted.elementBounds else {
            return false
        }

        return abs(trustedElementBounds.x - observedElementBounds.x) <= maximumGeometryDelta
            && abs(trustedElementBounds.y - observedElementBounds.y) <= maximumGeometryDelta
            && abs(trustedElementBounds.width - observedElementBounds.width) <= maximumGeometryDelta
            && trustedElementBounds.height > 0
            && observedElementBounds.height > 0
    }

    private func targetFingerprint(for context: FocusedTextContext) -> FocusedTargetFingerprint {
        FocusedTargetFingerprint(
            role: context.role,
            subrole: context.subrole,
            elementFingerprint: context.fingerprint,
            windowIdentifier: context.windowIdentifier,
            elementRect: context.elementRect,
            windowRect: context.windowRect,
            caretRect: context.caretRect,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )
    }

    private static let transientObservedRoles: Set<String> = [
        "AXTextArea",
        "AXWebArea"
    ]
}
