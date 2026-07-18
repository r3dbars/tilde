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

struct CodexPromptAXCooldownPreservation: Equatable {
    let fieldIdentity: FocusedFieldIdentity
    let expiresAtMilliseconds: Int
}

enum CodexPromptPresentationRefreshResolution: Equatable {
    case reject
    case cancelAndRetry
    case reuseTrustedTextAreaContext
    case retry
}

enum CodexPromptTargetInvalidationResolution: Equatable {
    case reject
    case preserveWork
    case cancelAndRetry
}

enum CodexPromptPresentationPreparation: Equatable {
    case deferForAXCooldown(delayMilliseconds: Int)
    case refreshFocusedContext
    case useOriginalContext
}

struct CodexPromptPresentationPreparationPolicy {
    func preparation(
        refreshBeforePresenting: Bool,
        cooldownDelayMilliseconds: Int
    ) -> CodexPromptPresentationPreparation {
        guard refreshBeforePresenting else {
            return .useOriginalContext
        }
        guard cooldownDelayMilliseconds > 0 else {
            return .refreshFocusedContext
        }

        return .deferForAXCooldown(delayMilliseconds: cooldownDelayMilliseconds)
    }
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
    static let maximumStablePromptAcceptanceAgeMilliseconds = 15_000

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
              let elementRect = context.elementRect,
              elementRect.width > 0,
              elementRect.height > 0,
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
        invalidationResolution(
            appBundleIdentifier: appBundleIdentifier,
            processIdentifier: processIdentifier,
            promptBlockReason: promptBlockReason,
            currentFieldIdentity: currentFieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: trustedAnchor,
            observedContext: observedContext,
            trustedContext: trustedContext,
            nowMilliseconds: nowMilliseconds,
            maximumAnchorAgeMilliseconds: maximumAnchorAgeMilliseconds
        ) == .preserveWork
    }

    func invalidationResolution(
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
    ) -> CodexPromptTargetInvalidationResolution {
        guard Self.transientPromptBlockReasons.contains(promptBlockReason),
              let verifiedObservation = verifiedTransientObservation(
                  appBundleIdentifier: appBundleIdentifier,
                  processIdentifier: processIdentifier,
                  currentFieldIdentity: currentFieldIdentity,
                  currentSnapshot: currentSnapshot,
                  trustedAnchor: trustedAnchor,
                  observedContext: observedContext,
                  nowMilliseconds: nowMilliseconds,
                  maximumAnchorAgeMilliseconds: maximumAnchorAgeMilliseconds
              ) else {
            return .reject
        }

        let currentSnapshot = verifiedObservation.currentSnapshot
        let trustedAnchor = verifiedObservation.trustedAnchor

        if let trustedContext {
            guard trustedContext.role == "AXTextArea",
                  trustedContext.selectedTextLength == 0,
                  trustedContext.elementRect != nil,
                  !trustedContext.isSecure,
                  trustedContext.textBeforeCursor == currentSnapshot.textBeforeCursor,
                  trustedContext.textAfterCursor == currentSnapshot.textAfterCursor,
                  trustedAnchor.targetFingerprint.matches(targetFingerprint(for: trustedContext)) else {
                return .reject
            }
        }

        return verifiedObservation.resolution
    }

    func presentationRefreshResolution(
        appBundleIdentifier: String,
        processIdentifier: Int32,
        promptBlockReason: String,
        currentFieldIdentity: FocusedFieldIdentity?,
        currentSnapshot: FocusedTextSnapshot?,
        trustedAnchor: CodexPromptTargetContinuityAnchor?,
        observedContext: FocusedTextContext,
        trustedContext: FocusedTextContext,
        nowMilliseconds: Int = Int(ProcessInfo.processInfo.systemUptime * 1_000)
    ) -> CodexPromptPresentationRefreshResolution {
        let invalidationResolution = invalidationResolution(
            appBundleIdentifier: appBundleIdentifier,
            processIdentifier: processIdentifier,
            promptBlockReason: promptBlockReason,
            currentFieldIdentity: currentFieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: trustedAnchor,
            observedContext: observedContext,
            trustedContext: trustedContext,
            nowMilliseconds: nowMilliseconds
        )
        guard invalidationResolution != .reject else {
            return .reject
        }
        guard invalidationResolution != .cancelAndRetry else {
            return .cancelAndRetry
        }

        guard observedContext.role == "AXTextArea",
              observedContext.elementIdentifier == trustedAnchor?.elementIdentifier,
              observedContext.textBeforeCursor == currentSnapshot?.textBeforeCursor,
              observedContext.textAfterCursor == currentSnapshot?.textAfterCursor else {
            return .retry
        }

        return .reuseTrustedTextAreaContext
    }

    func axCooldownPreservation(
        trustedAnchor: CodexPromptTargetContinuityAnchor?,
        cooldownMilliseconds: Int,
        nowMilliseconds: Int = Int(ProcessInfo.processInfo.systemUptime * 1_000)
    ) -> CodexPromptAXCooldownPreservation? {
        guard let trustedAnchor,
              cooldownMilliseconds > 0 else {
            return nil
        }

        return CodexPromptAXCooldownPreservation(
            fieldIdentity: trustedAnchor.fieldIdentity,
            expiresAtMilliseconds: nowMilliseconds + cooldownMilliseconds
        )
    }

    func canBeginAXCooldownPreservation(
        appBundleIdentifier: String,
        processIdentifier: Int32,
        currentFieldIdentity: FocusedFieldIdentity?,
        currentSnapshot: FocusedTextSnapshot?,
        trustedAnchor: CodexPromptTargetContinuityAnchor?,
        observedContext: FocusedTextContext,
        hasActiveSuggestionWork: Bool,
        nowMilliseconds: Int = Int(ProcessInfo.processInfo.systemUptime * 1_000),
        maximumAnchorAgeMilliseconds: Int = 1_000
    ) -> Bool {
        hasActiveSuggestionWork
            && axHealthInvalidationResolution(
                appBundleIdentifier: appBundleIdentifier,
                processIdentifier: processIdentifier,
                currentFieldIdentity: currentFieldIdentity,
                currentSnapshot: currentSnapshot,
                trustedAnchor: trustedAnchor,
                observedContext: observedContext,
                nowMilliseconds: nowMilliseconds,
                maximumAnchorAgeMilliseconds: maximumAnchorAgeMilliseconds
            ) == .preserveWork
    }

    func axHealthInvalidationResolution(
        appBundleIdentifier: String,
        processIdentifier: Int32,
        currentFieldIdentity: FocusedFieldIdentity?,
        currentSnapshot: FocusedTextSnapshot?,
        trustedAnchor: CodexPromptTargetContinuityAnchor?,
        observedContext: FocusedTextContext,
        nowMilliseconds: Int = Int(ProcessInfo.processInfo.systemUptime * 1_000),
        maximumAnchorAgeMilliseconds: Int = 1_000
    ) -> CodexPromptTargetInvalidationResolution {
        verifiedTransientObservation(
            appBundleIdentifier: appBundleIdentifier,
            processIdentifier: processIdentifier,
            currentFieldIdentity: currentFieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: trustedAnchor,
            observedContext: observedContext,
            nowMilliseconds: nowMilliseconds,
            maximumAnchorAgeMilliseconds: maximumAnchorAgeMilliseconds
        )?.resolution ?? .reject
    }

    func canPreserveDuringAXCooldown(
        appBundleIdentifier: String,
        processIdentifier: Int32,
        currentFieldIdentity: FocusedFieldIdentity?,
        currentSnapshot: FocusedTextSnapshot?,
        trustedAnchor: CodexPromptTargetContinuityAnchor?,
        preservation: CodexPromptAXCooldownPreservation?,
        hasActiveSuggestionWork: Bool,
        nowMilliseconds: Int = Int(ProcessInfo.processInfo.systemUptime * 1_000)
    ) -> Bool {
        guard appBundleIdentifier == CodexProofFocusedTargetPolicy.bundleIdentifier,
              hasActiveSuggestionWork,
              let currentFieldIdentity,
              let currentSnapshot,
              let trustedAnchor,
              let preservation,
              currentFieldIdentity == preservation.fieldIdentity,
              currentSnapshot.fieldIdentity == preservation.fieldIdentity,
              trustedAnchor.fieldIdentity == preservation.fieldIdentity,
              preservation.fieldIdentity.bundleIdentifier == appBundleIdentifier,
              preservation.fieldIdentity.processIdentifier == processIdentifier,
              nowMilliseconds <= preservation.expiresAtMilliseconds,
              trustedAnchor.targetFingerprint.surroundingTextRevision == FocusedTextRevision(
                textBeforeCursor: currentSnapshot.textBeforeCursor,
                textAfterCursor: currentSnapshot.textAfterCursor
              ) else {
            return false
        }

        return true
    }

    func canAcceptStablePrompt(
        appBundleIdentifier: String,
        processIdentifier: Int32,
        currentFieldIdentity: FocusedFieldIdentity?,
        currentSnapshot: FocusedTextSnapshot?,
        shownSnapshot: SuggestionAcceptanceSnapshot,
        trustedAnchor: CodexPromptTargetContinuityAnchor?,
        observedContext: FocusedTextContext,
        nowMilliseconds: Int = Int(ProcessInfo.processInfo.systemUptime * 1_000),
        maximumAnchorAgeMilliseconds: Int = Self.maximumStablePromptAcceptanceAgeMilliseconds
    ) -> Bool {
        guard observedContext.role == "AXTextArea",
              shownSnapshot.selectedTextLength == 0,
              let currentFieldIdentity,
              let currentSnapshot,
              let trustedAnchor,
              shownSnapshot.fieldIdentity == currentFieldIdentity,
              shownSnapshot.fieldIdentity == currentSnapshot.fieldIdentity,
              shownSnapshot.textBeforeCursor == currentSnapshot.textBeforeCursor,
              shownSnapshot.textAfterCursor == currentSnapshot.textAfterCursor,
              shownSnapshot.targetFingerprint.surroundingTextRevision == FocusedTextRevision(
                  textBeforeCursor: currentSnapshot.textBeforeCursor,
                  textAfterCursor: currentSnapshot.textAfterCursor
              ),
              targetMatchesTrustedAnchor(
                  shownSnapshot.targetFingerprint,
                  trustedAnchor: trustedAnchor
              ),
              targetMatchesTrustedAnchor(
                  targetFingerprint(for: observedContext),
                  trustedAnchor: trustedAnchor
              ) else {
            return false
        }

        return verifiedTransientObservation(
            appBundleIdentifier: appBundleIdentifier,
            processIdentifier: processIdentifier,
            currentFieldIdentity: currentFieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: trustedAnchor,
            observedContext: observedContext,
            nowMilliseconds: nowMilliseconds,
            maximumAnchorAgeMilliseconds: maximumAnchorAgeMilliseconds
        )?.resolution == .preserveWork
    }

    private func targetMatchesTrustedAnchor(
        _ target: FocusedTargetFingerprint,
        trustedAnchor: CodexPromptTargetContinuityAnchor,
        maximumGeometryDelta: Int = 4
    ) -> Bool {
        let trustedTarget = trustedAnchor.targetFingerprint
        guard target.role == trustedTarget.role,
              target.subrole == trustedTarget.subrole,
              hasAffirmativeSameWindowEvidence(
                  target,
                  trustedTarget
              ),
              let targetElementBounds = target.elementBounds,
              let trustedElementBounds = trustedTarget.elementBounds else {
            return false
        }

        return abs(targetElementBounds.x - trustedElementBounds.x) <= maximumGeometryDelta
            && abs(targetElementBounds.y - trustedElementBounds.y) <= maximumGeometryDelta
            && abs(targetElementBounds.width - trustedElementBounds.width) <= maximumGeometryDelta
            && abs(targetElementBounds.height - trustedElementBounds.height) <= maximumGeometryDelta
            && targetElementBounds.width > 0
            && targetElementBounds.height > 0
            && trustedElementBounds.width > 0
            && trustedElementBounds.height > 0
    }

    private func hasAffirmativeSameWindowEvidence(
        _ shownTarget: FocusedTargetFingerprint,
        _ trustedTarget: FocusedTargetFingerprint
    ) -> Bool {
        if shownTarget.windowIdentifier != nil
            || trustedTarget.windowIdentifier != nil {
            return shownTarget.windowIdentifier == trustedTarget.windowIdentifier
        }

        return shownTarget.windowBounds != nil
            && shownTarget.windowBounds == trustedTarget.windowBounds
            && shownTarget.elementFingerprint.windowTitle != nil
            && shownTarget.elementFingerprint.windowTitle == trustedTarget.elementFingerprint.windowTitle
    }

    func remainingAXCooldownMilliseconds(
        preservation: CodexPromptAXCooldownPreservation?,
        nowMilliseconds: Int = Int(ProcessInfo.processInfo.systemUptime * 1_000)
    ) -> Int {
        guard let preservation else {
            return 0
        }

        return max(0, preservation.expiresAtMilliseconds - nowMilliseconds)
    }

    private func verifiedTransientObservation(
        appBundleIdentifier: String,
        processIdentifier: Int32,
        currentFieldIdentity: FocusedFieldIdentity?,
        currentSnapshot: FocusedTextSnapshot?,
        trustedAnchor: CodexPromptTargetContinuityAnchor?,
        observedContext: FocusedTextContext,
        nowMilliseconds: Int,
        maximumAnchorAgeMilliseconds: Int
    ) -> (
        currentSnapshot: FocusedTextSnapshot,
        trustedAnchor: CodexPromptTargetContinuityAnchor,
        resolution: CodexPromptTargetInvalidationResolution
    )? {
        guard appBundleIdentifier == CodexProofFocusedTargetPolicy.bundleIdentifier,
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
              let resolution = observationTextResolution(
                  currentSnapshot,
                  observedContext: observedContext
              ),
              resolution != .cancelAndRetry
                || observedContext.role != "AXTextArea"
                || observedContext.elementIdentifier == trustedAnchor.elementIdentifier,
              trustedAnchor.targetFingerprint.surroundingTextRevision == FocusedTextRevision(
                  textBeforeCursor: currentSnapshot.textBeforeCursor,
                  textAfterCursor: currentSnapshot.textAfterCursor
              ),
              observationDoesNotConflict(
                  trustedAnchor,
                  observedContext: observedContext
              ) else {
            return nil
        }

        return (
            currentSnapshot: currentSnapshot,
            trustedAnchor: trustedAnchor,
            resolution: resolution
        )
    }

    private func observationTextResolution(
        _ currentSnapshot: FocusedTextSnapshot,
        observedContext: FocusedTextContext
    ) -> CodexPromptTargetInvalidationResolution? {
        if observedContext.textBeforeCursor == currentSnapshot.textBeforeCursor,
           observedContext.textAfterCursor == currentSnapshot.textAfterCursor {
            return .preserveWork
        }

        switch observedContext.role {
        case "AXWebArea":
            guard observedContext.textBeforeCursor.isEmpty,
                  observedContext.textAfterCursor.isEmpty else {
                return nil
            }
            return .cancelAndRetry
        case "AXTextArea":
            guard currentSnapshot.textAfterCursor.isEmpty,
                  !currentSnapshot.textBeforeCursor.isEmpty,
                  observedContext.textBeforeCursor.isEmpty,
                  observedContext.textAfterCursor.hasPrefix(currentSnapshot.textBeforeCursor) else {
                return nil
            }
            return .cancelAndRetry
        default:
            return nil
        }
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

        // AXWebArea is a transient wrapper in Codex, so its element bounds and
        // identifier are not composer identity. Require affirmative same-window
        // evidence before preserving work through that wrapper.
        if observedContext.role == "AXWebArea" {
            let identifiersMatch = trusted.windowIdentifier != nil
                && trusted.windowIdentifier == observed.windowIdentifier
            let boundsAndTitleMatch = trusted.windowBounds != nil
                && trusted.windowBounds == observed.windowBounds
                && trusted.elementFingerprint.windowTitle != nil
                && trusted.elementFingerprint.windowTitle == observed.elementFingerprint.windowTitle

            return identifiersMatch || boundsAndTitleMatch
        }

        guard observedContext.role == "AXTextArea",
              let observedElementBounds = observed.elementBounds else {
            return observedContext.elementIdentifier == trustedAnchor.elementIdentifier
        }

        guard let trustedElementBounds = trusted.elementBounds else {
            return false
        }

        return abs(trustedElementBounds.x - observedElementBounds.x) <= maximumGeometryDelta
            && abs(trustedElementBounds.y - observedElementBounds.y) <= maximumGeometryDelta
            && abs(trustedElementBounds.width - observedElementBounds.width) <= maximumGeometryDelta
            && abs(trustedElementBounds.height - observedElementBounds.height) <= maximumGeometryDelta
            && trustedElementBounds.width > 0
            && observedElementBounds.width > 0
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
