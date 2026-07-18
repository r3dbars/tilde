import Foundation
import AutocompleteLabCore

@MainActor
struct SuggestionInsertionHostDependencies {
    let currentProfile: () -> CompatibilityProfile?
    let currentSuggestionState: CurrentSuggestionStateHost
    let currentFieldIdentity: () -> FocusedFieldIdentity?
    let acceptedTextSafetyPolicy: AcceptedTextSafetyPolicy
    let setSuggestionDecision: (String) -> Void
    let hideSuggestion: (String) -> Void
    let suppressPassthroughObservation: (Date) -> Void
    let shouldUseClaudeCodeTerminalHostProofDirectInsertion: (CompatibilityProfile, KeyboardAction?) -> Bool
    let shouldUseCodexProofDirectInsertion: (CompatibilityProfile) -> Bool
    let shouldUseClaudeDesktopProofDirectInsertion: (CompatibilityProfile) -> Bool
    let shouldUseObsidianDirectValueInsertion: (CompatibilityProfile, KeyboardAction?) -> Bool
    let shouldUseObsidianSystemEventsInsertion: (CompatibilityProfile) -> Bool
    let insertCodexProofText: (String) -> Bool
    let insertClaudeCodeTerminalHostProofText: (String) -> Bool
    let insertClaudeDesktopProofText: (String) -> Bool
    let insertObsidianDirectValueText: (String, CompatibilityProfile) -> Bool
    let insertObsidianSystemEventsPasteText: (String) -> Bool
    let repairObsidianFullAcceptCaret: (CompatibilityProfile, KeyboardAction?) -> Void
    let defaultInsertion: (String, CompatibilityProfile, FocusedFieldIdentity?, Set<InsertionMode>) -> InsertionResult
    let pausePolling: (Int) -> Void
    let postInsertionPollPauseMilliseconds: Int
}

/// Owns accepted-text routing while app-specific insertion implementations remain injected.
@MainActor
final class SuggestionInsertionHost {
    private let dependencies: SuggestionInsertionHostDependencies

    init(dependencies: SuggestionInsertionHostDependencies) {
        self.dependencies = dependencies
    }

    private var currentProfile: CompatibilityProfile? {
        dependencies.currentProfile()
    }

    private var currentSuggestionState: CurrentSuggestionStateHost {
        dependencies.currentSuggestionState
    }

    private var currentFieldIdentity: FocusedFieldIdentity? {
        dependencies.currentFieldIdentity()
    }

    private var acceptedTextSafetyPolicy: AcceptedTextSafetyPolicy {
        dependencies.acceptedTextSafetyPolicy
    }

    private var postInsertionPollPauseMilliseconds: Int {
        dependencies.postInsertionPollPauseMilliseconds
    }

    private func setSuggestionDecision(_ decision: String) {
        dependencies.setSuggestionDecision(decision)
    }

    private func hideSuggestion(reason: String) {
        dependencies.hideSuggestion(reason)
    }

    private func suppressPassthroughObservation(for interval: TimeInterval) {
        dependencies.suppressPassthroughObservation(
            Date().addingTimeInterval(interval)
        )
    }

    private func pausePolling() {
        dependencies.pausePolling(postInsertionPollPauseMilliseconds)
    }

    private func defaultInsertion(
        _ acceptedText: String,
        profile: CompatibilityProfile,
        expectedFieldIdentity: FocusedFieldIdentity?,
        skipping skippedModes: Set<InsertionMode>
    ) -> InsertionResult {
        dependencies.defaultInsertion(acceptedText, profile, expectedFieldIdentity, skippedModes)
    }

    func insertAcceptedText(
        _ acceptedText: String,
        skippingInsertionModes skippedModes: Set<InsertionMode> = [],
        action: KeyboardAction? = nil
    ) -> Bool {
        guard let profile = currentProfile else {
            setSuggestionDecision("Blocked: missing compatibility profile")
            DiagnosticsLog.shared.record(
                "insert-blocked",
                metadata: [
                    "reason": "missing-compatibility-profile",
                    "acceptedChars": String(acceptedText.count)
                ]
            )
            RawAutocompleteTraceLog.shared.record(
                type: .insertionFailed,
                suggestionID: currentSuggestionState.id ?? "",
                appBundleIdentifier: currentSuggestionState.appBundleIdentifier ?? "",
                fieldIdentity: currentSuggestionState.fieldIdentity?.traceDescription
                    ?? currentFieldIdentity?.traceDescription
                    ?? "",
                requestMode: currentSuggestionState.requestMode?.rawValue ?? "",
                acceptedText: acceptedText,
                reason: "missing-compatibility-profile",
                metadata: [
                    "safetyGate": "compatibilityProfile"
                ]
            )
            hideSuggestion(reason: "insert-missing-compatibility-profile")
            return false
        }

        let acceptedTextDecision = acceptedTextSafetyPolicy.decision(
            acceptedText: acceptedText,
            profile: profile,
            allowsPromptActionWords: dependencies.shouldUseClaudeCodeTerminalHostProofDirectInsertion(
                profile,
                action
            )
        )
        if let blockReason = acceptedTextDecision.blockReason {
            setSuggestionDecision("Blocked: unsafe accepted text")
            DiagnosticsLog.shared.record(
                "insert-blocked",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "reason": blockReason,
                    "acceptedChars": String(acceptedText.count),
                    "promptSafetyMode": profile.promptAppSafetyMode.rawValue
                ]
            )
            RawAutocompleteTraceLog.shared.record(
                type: .insertionFailed,
                suggestionID: currentSuggestionState.id ?? "",
                appBundleIdentifier: currentSuggestionState.appBundleIdentifier ?? profile.bundleIdentifier,
                fieldIdentity: currentSuggestionState.fieldIdentity?.traceDescription
                    ?? currentFieldIdentity?.traceDescription
                    ?? "",
                requestMode: currentSuggestionState.requestMode?.rawValue ?? "",
                acceptedText: acceptedText,
                reason: blockReason,
                metadata: [
                    "safetyGate": "acceptedText",
                    "promptSafetyMode": profile.promptAppSafetyMode.rawValue
                ]
            )
            hideSuggestion(reason: "insert-unsafe-accepted-text")
            return false
        }

        suppressPassthroughObservation(
            for: dependencies.shouldUseClaudeCodeTerminalHostProofDirectInsertion(profile, action)
                || dependencies.shouldUseCodexProofDirectInsertion(profile)
                || dependencies.shouldUseClaudeDesktopProofDirectInsertion(profile)
                || dependencies.shouldUseObsidianDirectValueInsertion(profile, action)
                || dependencies.shouldUseObsidianSystemEventsInsertion(profile) ? 0.75 : 0.25
        )

        if dependencies.shouldUseCodexProofDirectInsertion(profile) {
            let succeeded = dependencies.insertCodexProofText(acceptedText)
            DiagnosticsLog.shared.record(
                "insert",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "mode": InsertionMode.axValueReplacement.rawValue,
                    "promptSafetyMode": profile.promptAppSafetyMode.rawValue,
                    "success": String(succeeded),
                    "skippedModes": skippedModes
                        .map(\.rawValue)
                        .sorted()
                        .joined(separator: ",")
                ]
            )
            if succeeded {
                pausePolling()
            }
            return succeeded
        }

        if dependencies.shouldUseClaudeCodeTerminalHostProofDirectInsertion(profile, action) {
            let succeeded = dependencies.insertClaudeCodeTerminalHostProofText(acceptedText)
            DiagnosticsLog.shared.record(
                "insert",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "mode": InsertionMode.clipboardFallbackOptIn.rawValue,
                    "promptSafetyMode": profile.promptAppSafetyMode.rawValue,
                    "success": String(succeeded),
                    "skippedModes": skippedModes
                        .map(\.rawValue)
                        .sorted()
                        .joined(separator: ",")
                ]
            )
            if succeeded {
                pausePolling()
            }
            return succeeded
        }

        if dependencies.shouldUseClaudeDesktopProofDirectInsertion(profile) {
            let succeeded = dependencies.insertClaudeDesktopProofText(acceptedText)
            DiagnosticsLog.shared.record(
                "insert",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "mode": InsertionMode.axValueReplacement.rawValue,
                    "promptSafetyMode": profile.promptAppSafetyMode.rawValue,
                    "success": String(succeeded),
                    "skippedModes": skippedModes
                        .map(\.rawValue)
                        .sorted()
                        .joined(separator: ",")
                ]
            )
            if succeeded {
                pausePolling()
            }
            return succeeded
        }

        if dependencies.shouldUseObsidianDirectValueInsertion(profile, action) {
            let succeeded = dependencies.insertObsidianDirectValueText(acceptedText, profile)
            DiagnosticsLog.shared.record(
                "insert",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "mode": InsertionMode.axValueReplacement.rawValue,
                    "promptSafetyMode": profile.promptAppSafetyMode.rawValue,
                    "success": String(succeeded),
                    "skippedModes": skippedModes
                        .map(\.rawValue)
                        .sorted()
                        .joined(separator: ",")
                ]
            )
            if succeeded {
                pausePolling()
            }
            return succeeded
        }

        if dependencies.shouldUseObsidianSystemEventsInsertion(profile) {
            let succeeded = dependencies.insertObsidianSystemEventsPasteText(acceptedText)
            DiagnosticsLog.shared.record(
                "insert",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "mode": InsertionMode.clipboardFallbackOptIn.rawValue,
                    "promptSafetyMode": profile.promptAppSafetyMode.rawValue,
                    "success": String(succeeded),
                    "skippedModes": skippedModes
                        .map(\.rawValue)
                        .sorted()
                        .joined(separator: ",")
                ]
            )
            if succeeded {
                pausePolling()
            }
            return succeeded
        }

        dependencies.repairObsidianFullAcceptCaret(profile, action)

        // Bind the Accessibility write to the field the suggestion was shown for, so focus
        // stolen between the acceptance guard and the write cannot redirect the user's accepted
        // text into another app/field. See docs/security/threat-model.md (F1).
        let result = defaultInsertion(
            acceptedText,
            profile: profile,
            expectedFieldIdentity: currentSuggestionState.fieldIdentity,
            skipping: skippedModes
        )
        DiagnosticsLog.shared.record(
            "insert",
            metadata: [
                "app": profile.bundleIdentifier,
                "mode": result.mode.rawValue,
                "promptSafetyMode": profile.promptAppSafetyMode.rawValue,
                "success": String(result.succeeded),
                "skippedModes": skippedModes
                    .map(\.rawValue)
                    .sorted()
                    .joined(separator: ",")
            ]
        )

        if result.succeeded {
            pausePolling()
        }

        return result.succeeded
    }
}
