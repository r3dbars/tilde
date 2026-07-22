import AutocompleteLabCore
import Foundation

@MainActor
struct SuggestionNextWordAcceptanceInput {
    let acceptedText: String
    let acceptanceID: String
    let acceptedAt: Date
    let action: KeyboardAction
    let acceptanceProof: SuggestionAcceptanceProof
    let verificationBaseline: InsertionVerificationBaseline?
}

@MainActor
struct SuggestionAcceptanceHostDependencies {
    let keyboardShortcutConfiguration: () -> KeyboardShortcutConfiguration
    let suggestionSession: SuggestionSessionHost
    let currentSuggestionState: CurrentSuggestionStateHost
    let currentProfile: () -> CompatibilityProfile?
    let keyboardCaptureSafetyPolicy: KeyboardCaptureSafetyPolicy
    let suggestionOrchestrator: SuggestionOrchestrator
    let requestSuggestionNow: (String) -> Void
    let undoAcceptedInsertion: () -> Bool
    let acceptedInsertionUndoIsActive: () -> Bool
    let clearPendingAcceptedInsertionUndo: (String) -> Void
    let suppressKey: (AutocompleteKey) -> Void
    let clearKeySuppression: (AutocompleteKey) -> Void
    let setPreservesResidualSuggestionAfterNextWordAccept: (Bool) -> Void
    let shouldSuppressKey: (AutocompleteKey, Bool) -> Bool
    let focusedFieldMatchesCurrentSuggestion: (Bool) -> Bool
    let setSuggestionDecision: (String) -> Void
    let hideSuggestion: (String, [String: String]) -> Void
    let recordKeyboardAction: (AutocompleteKey, KeyboardAction, Bool, String) -> Void
    let currentSuggestionAcceptanceDecision: (Bool) -> SuggestionAcceptanceDecision
    let recordAcceptanceGuardBlock: (SuggestionAcceptanceBlockReason) -> Void
    let insertionVerificationBaseline: (String, Date, KeyboardAction, String) -> InsertionVerificationBaseline?
    let acceptedTextForCurrentAcceptance: (String, KeyboardAction) -> String
    let suggestionAcceptanceProof: (KeyboardAction, String) -> SuggestionAcceptanceProof?
    let insertAcceptedText: (String, KeyboardAction) -> Bool
    let suppressCurrentFieldAfterInsertionFailure: (String) -> Void
    let completeNextWordAcceptance: (SuggestionNextWordAcceptanceInput) -> Void
    let armAcceptedInsertionUndo: (String, String, Date, String) -> Void
    let recordAcceptedText: (String) -> Void
    let armObsidianPostAcceptanceSuppressionIfNeeded: () -> Void
    let recordRawAcceptance: (KeyboardAction, String, String, SuggestionAcceptanceProof) -> Void
    let currentAnnoyanceContext: () -> AnnoyanceContext?
    let recordAnnoyanceSignal: (AnnoyanceSignal, AnnoyanceContext?, String, String, [String: String]) -> Void
    let scheduleInsertionVerification: (String, InsertionVerificationBaseline?) -> Void
    let currentSuggestionLifetimeMetadata: () -> [String: String]
    let currentPrefixFamilyCooldownInput: () -> PrefixFamilyCooldownInput?
    let recordPrefixFamilyCooldown: (PrefixFamilyCooldownReason, PrefixFamilyCooldownInput) -> [String: String]
    let suppressCurrentField: (String) -> Void
}

/// Owns keyboard acceptance routing and acceptance handoff; acceptance and insertion policies remain injected.
@MainActor
final class SuggestionAcceptanceHost {
    private let dependencies: SuggestionAcceptanceHostDependencies

    init(dependencies: SuggestionAcceptanceHostDependencies) {
        self.dependencies = dependencies
    }

    private var keyboardShortcutConfiguration: KeyboardShortcutConfiguration {
        dependencies.keyboardShortcutConfiguration()
    }

    private var suggestionSession: SuggestionSessionHost {
        dependencies.suggestionSession
    }

    private var currentSuggestionState: CurrentSuggestionStateHost {
        dependencies.currentSuggestionState
    }

    private var currentProfile: CompatibilityProfile? {
        dependencies.currentProfile()
    }

    private var keyboardCaptureSafetyPolicy: KeyboardCaptureSafetyPolicy {
        dependencies.keyboardCaptureSafetyPolicy
    }

    private var suggestionOrchestrator: SuggestionOrchestrator {
        dependencies.suggestionOrchestrator
    }

    private func requestSuggestionNow(source: String) {
        dependencies.requestSuggestionNow(source)
    }

    private func undoAcceptedInsertion() -> Bool {
        dependencies.undoAcceptedInsertion()
    }

    private func acceptedInsertionUndoIsActive() -> Bool {
        dependencies.acceptedInsertionUndoIsActive()
    }

    private func clearPendingAcceptedInsertionUndo(reason: String) {
        dependencies.clearPendingAcceptedInsertionUndo(reason)
    }

    private func suppressKey(_ key: AutocompleteKey) {
        dependencies.suppressKey(key)
    }

    private func shouldSuppressKey(_ key: AutocompleteKey, isAutorepeat: Bool) -> Bool {
        dependencies.shouldSuppressKey(key, isAutorepeat)
    }

    private func focusedFieldMatchesCurrentSuggestion(
        allowObsidianSnapshotFastPath: Bool = false
    ) -> Bool {
        dependencies.focusedFieldMatchesCurrentSuggestion(allowObsidianSnapshotFastPath)
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

    private func recordKeyboardAction(
        key: AutocompleteKey,
        action: KeyboardAction,
        handled: Bool,
        reason: String
    ) {
        dependencies.recordKeyboardAction(key, action, handled, reason)
    }

    private func currentSuggestionAcceptanceDecision(
        allowObsidianSnapshotFastPath: Bool = false
    ) -> SuggestionAcceptanceDecision {
        dependencies.currentSuggestionAcceptanceDecision(allowObsidianSnapshotFastPath)
    }

    private func recordAcceptanceGuardBlock(reason: SuggestionAcceptanceBlockReason) {
        dependencies.recordAcceptanceGuardBlock(reason)
    }

    private func insertionVerificationBaseline(
        acceptanceID: String,
        acceptedAt: Date,
        action: KeyboardAction,
        acceptMode: String
    ) -> InsertionVerificationBaseline? {
        dependencies.insertionVerificationBaseline(acceptanceID, acceptedAt, action, acceptMode)
    }

    private func acceptedTextForCurrentAcceptance(
        _ acceptedText: String,
        action: KeyboardAction
    ) -> String {
        dependencies.acceptedTextForCurrentAcceptance(acceptedText, action)
    }

    private func suggestionAcceptanceProof(
        action: KeyboardAction,
        acceptedText: String
    ) -> SuggestionAcceptanceProof? {
        dependencies.suggestionAcceptanceProof(action, acceptedText)
    }

    private func insertAcceptedText(_ acceptedText: String, action: KeyboardAction) -> Bool {
        dependencies.insertAcceptedText(acceptedText, action)
    }

    private func suppressCurrentFieldAfterInsertionFailure(reason: String) {
        dependencies.suppressCurrentFieldAfterInsertionFailure(reason)
    }

    private func completeNextWordAcceptance(
        acceptedText: String,
        acceptanceID: String,
        acceptedAt: Date,
        action: KeyboardAction,
        acceptanceProof: SuggestionAcceptanceProof,
        verificationBaseline: InsertionVerificationBaseline?
    ) {
        dependencies.completeNextWordAcceptance(
            SuggestionNextWordAcceptanceInput(
                acceptedText: acceptedText,
                acceptanceID: acceptanceID,
                acceptedAt: acceptedAt,
                action: action,
                acceptanceProof: acceptanceProof,
                verificationBaseline: verificationBaseline
            )
        )
    }

    private func armAcceptedInsertionUndo(
        acceptedText: String,
        acceptanceID: String,
        acceptedAt: Date,
        acceptMode: String
    ) {
        dependencies.armAcceptedInsertionUndo(acceptedText, acceptanceID, acceptedAt, acceptMode)
    }

    private func recordAcceptedText(_ acceptedText: String) {
        dependencies.recordAcceptedText(acceptedText)
    }

    private func armObsidianPostAcceptanceSuppressionIfNeeded() {
        dependencies.armObsidianPostAcceptanceSuppressionIfNeeded()
    }

    private func recordRawAcceptance(
        action: KeyboardAction,
        acceptedText: String,
        acceptanceID: String,
        acceptanceProof: SuggestionAcceptanceProof
    ) {
        dependencies.recordRawAcceptance(action, acceptedText, acceptanceID, acceptanceProof)
    }

    private func currentAnnoyanceContext() -> AnnoyanceContext? {
        dependencies.currentAnnoyanceContext()
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

    private func scheduleInsertionVerification(
        acceptedText: String,
        baseline: InsertionVerificationBaseline?
    ) {
        dependencies.scheduleInsertionVerification(acceptedText, baseline)
    }

    private func currentSuggestionLifetimeMetadata() -> [String: String] {
        dependencies.currentSuggestionLifetimeMetadata()
    }

    private func currentPrefixFamilyCooldownInput() -> PrefixFamilyCooldownInput? {
        dependencies.currentPrefixFamilyCooldownInput()
    }

    private func recordPrefixFamilyCooldown(
        _ reason: PrefixFamilyCooldownReason,
        input: PrefixFamilyCooldownInput
    ) -> [String: String] {
        dependencies.recordPrefixFamilyCooldown(reason, input)
    }

    private func suppressCurrentField(reason: String) {
        dependencies.suppressCurrentField(reason)
    }

    func handleAutocompleteKey(
        _ key: AutocompleteKey,
        isAutorepeat: Bool = false,
        didObservePassthroughKeyDown: Bool = false
    ) -> KeyboardEventTapHandlingResult {
        if didObservePassthroughKeyDown {
            currentSuggestionState.invalidatedByUserKeyDown = true
            dependencies.setPreservesResidualSuggestionAfterNextWordAccept(false)
            clearPendingAcceptedInsertionUndo(reason: "typing")
        }

        let action = KeyboardActionRouter(shortcutConfiguration: keyboardShortcutConfiguration).action(
            for: key,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
            hasPendingAcceptedInsertionUndo: acceptedInsertionUndoIsActive()
        )

        if action == .requestSuggestionNow {
            requestSuggestionNow(source: "key-tap")
            suppressKey(key)
            recordKeyboardAction(
                key: key,
                action: action,
                handled: true,
                reason: "requested"
            )
            return .handled
        }

        if action == .undoAcceptedInsertion {
            let handled = undoAcceptedInsertion()
            if handled {
                suppressKey(key)
            }
            recordKeyboardAction(
                key: key,
                action: action,
                handled: handled,
                reason: handled ? "accepted-insertion-undone" : "undo-unavailable"
            )
            return handled ? .handled : .replayOriginalKey(.undoUnavailable)
        }

        guard suggestionSession.hasVisibleSuggestion else {
            dependencies.clearKeySuppression(key)
            return .replayOriginalKey(.noVisibleSuggestion)
        }

        guard focusedFieldMatchesCurrentSuggestion(
            allowObsidianSnapshotFastPath: action.insertsSuggestionText
        ) else {
            setSuggestionDecision("Blocked: focus changed")
            hideSuggestion(reason: "focus-changed")
            recordKeyboardAction(
                key: key,
                action: .passThrough,
                handled: false,
                reason: "focus-changed"
            )
            return keyboardCaptureSafetyPolicy.handlingResultForFocusMismatch(key: key)
        }

        if currentSuggestionState.invalidatedByUserKeyDown {
            setSuggestionDecision("Blocked: stale suggestion passed through")
            hideSuggestion(reason: "stale-after-keydown")
            recordKeyboardAction(
                key: key,
                action: .passThrough,
                handled: false,
                reason: "stale-after-keydown"
            )
            return .replayOriginalKey(.staleAfterTyping)
        }

        if shouldSuppressKey(key, isAutorepeat: isAutorepeat) {
            recordKeyboardAction(key: key, action: .passThrough, handled: true, reason: "suppressed-autorepeat")
            return .handled
        }

        switch action {
        case .requestSuggestionNow:
            return .replayOriginalKey(.passThroughAction)

        case .undoAcceptedInsertion:
            return .replayOriginalKey(.undoUnavailable)

        case .acceptNextWord:
            guard currentProfile?.supportsOneWordAcceptance == true else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "unsupported-one-word")
                return .replayOriginalKey(.unsupportedAction)
            }
            if let blockReason = currentSuggestionAcceptanceDecision(
                allowObsidianSnapshotFastPath: true
            ).blockReason {
                recordAcceptanceGuardBlock(reason: blockReason)
                setSuggestionDecision("Blocked: \(blockReason.rawValue)")
                hideSuggestion(reason: blockReason.rawValue)
                recordKeyboardAction(key: key, action: action, handled: false, reason: blockReason.rawValue)
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceBlock: blockReason, key: key)
            }

            let acceptanceID = UUID().uuidString
            let acceptedAt = Date()
            let verificationBaseline = insertionVerificationBaseline(
                acceptanceID: acceptanceID,
                acceptedAt: acceptedAt,
                action: action,
                acceptMode: action.diagnosticName
            )
            guard let rawAcceptedText = suggestionSession.nextWordAcceptance() else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "missing-accepted-text")
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceFailure: .missingAcceptedText)
            }
            let acceptedText = acceptedTextForCurrentAcceptance(rawAcceptedText, action: action)
            guard let acceptanceProof = suggestionAcceptanceProof(action: action, acceptedText: acceptedText) else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "acceptance-proof-failed")
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceFailure: .acceptanceProofFailed)
            }
            guard insertAcceptedText(acceptedText, action: action) else {
                suppressCurrentFieldAfterInsertionFailure(reason: "insert-failed")
                recordKeyboardAction(key: key, action: action, handled: false, reason: "insert-failed")
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceFailure: .insertionFailed)
            }

            completeNextWordAcceptance(
                acceptedText: acceptedText,
                acceptanceID: acceptanceID,
                acceptedAt: acceptedAt,
                action: action,
                acceptanceProof: acceptanceProof,
                verificationBaseline: verificationBaseline
            )
            suppressKey(key)
            recordKeyboardAction(key: key, action: action, handled: true, reason: "accepted")
            return .handled

        case .acceptAllVisible:
            guard currentProfile?.supportsFullAcceptance == true else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "unsupported-full")
                return .replayOriginalKey(.unsupportedAction)
            }
            if let blockReason = currentSuggestionAcceptanceDecision(
                allowObsidianSnapshotFastPath: true
            ).blockReason {
                recordAcceptanceGuardBlock(reason: blockReason)
                setSuggestionDecision("Blocked: \(blockReason.rawValue)")
                hideSuggestion(reason: blockReason.rawValue)
                recordKeyboardAction(key: key, action: action, handled: false, reason: blockReason.rawValue)
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceBlock: blockReason, key: key)
            }

            let acceptanceID = UUID().uuidString
            let acceptedAt = Date()
            let verificationBaseline = insertionVerificationBaseline(
                acceptanceID: acceptanceID,
                acceptedAt: acceptedAt,
                action: action,
                acceptMode: action.diagnosticName
            )
            guard let acceptedText = suggestionSession.allVisibleAcceptance() else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "missing-accepted-text")
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceFailure: .missingAcceptedText)
            }
            guard let acceptanceProof = suggestionAcceptanceProof(action: action, acceptedText: acceptedText) else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "acceptance-proof-failed")
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceFailure: .acceptanceProofFailed)
            }
            guard insertAcceptedText(acceptedText, action: action) else {
                suppressCurrentFieldAfterInsertionFailure(reason: "insert-failed")
                recordKeyboardAction(key: key, action: action, handled: false, reason: "insert-failed")
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceFailure: .insertionFailed)
            }

            armAcceptedInsertionUndo(
                acceptedText: acceptedText,
                acceptanceID: acceptanceID,
                acceptedAt: acceptedAt,
                acceptMode: action.diagnosticName
            )
            suggestionSession.commitAllVisibleAcceptance(acceptedText)
            recordAcceptedText(acceptedText)
            armObsidianPostAcceptanceSuppressionIfNeeded()
            suggestionOrchestrator.recordRepetitionAcceptance(
                acceptedText,
                mode: currentSuggestionState.requestMode,
                scope: currentSuggestionState.appBundleIdentifier ?? currentProfile?.bundleIdentifier ?? ""
            )
            recordRawAcceptance(
                action: action,
                acceptedText: acceptedText,
                acceptanceID: acceptanceID,
                acceptanceProof: acceptanceProof
            )
            recordAnnoyanceSignal(
                .accepted,
                context: currentAnnoyanceContext(),
                suggestionID: currentSuggestionState.id ?? "",
                reason: action.diagnosticName
            )
            setSuggestionDecision("Accepted: full suggestion")
            hideSuggestion(reason: "accepted-all")
            scheduleInsertionVerification(acceptedText: acceptedText, baseline: verificationBaseline)
            suppressKey(key)
            recordKeyboardAction(key: key, action: action, handled: true, reason: "accepted")
            return .handled

        case .dismiss:
            var metadata = currentSuggestionLifetimeMetadata()
            metadata["escapeDismissalInsertedText"] = String(action.insertsSuggestionText)
            metadata["escapeDismissalInsertedTextChars"] = "0"
            if let input = currentPrefixFamilyCooldownInput() {
                metadata.merge(recordPrefixFamilyCooldown(.escapeDismissal, input: input)) { current, _ in current }
            }
            recordAnnoyanceSignal(
                .rapidEscDismissal,
                context: currentAnnoyanceContext(),
                suggestionID: currentSuggestionState.id ?? "",
                reason: "escape",
                metadata: metadata
            )
            suppressCurrentField(reason: "escape")
            hideSuggestion(
                reason: "escape",
                metadata: [
                    "escapeDismissalInsertedText": String(action.insertsSuggestionText),
                    "escapeDismissalInsertedTextChars": "0"
                ]
            )
            suppressKey(key)
            recordKeyboardAction(key: key, action: action, handled: true, reason: "dismissed")
            return .handled

        case .passThrough:
            if key != .other {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "pass-through")
            }
            return .replayOriginalKey(.passThroughAction)
        }
    }
}
