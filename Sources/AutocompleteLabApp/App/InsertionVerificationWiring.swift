import AutocompleteLabCore

// MARK: - Insertion verification host

extension AppDelegate: InsertionVerificationHandling {
    func insertionVerificationContext(
        for baseline: InsertionVerificationBaseline,
        acceptedText: String
    ) -> FocusedInsertionVerificationContext {
        focusedInsertionVerificationContext(for: baseline, acceptedText: acceptedText)
    }

    func retryAcceptedInsertion(
        _ acceptedText: String,
        skippingInsertionModes: Set<InsertionMode>,
        action: KeyboardAction?
    ) -> Bool {
        insertAcceptedText(
            acceptedText,
            skippingInsertionModes: skippingInsertionModes,
            action: action
        )
    }

    func handleInsertionVerificationFailure(
        acceptedText: String,
        baseline: InsertionVerificationBaseline,
        context: FocusedTextContext,
        result: InsertionVerificationResult
    ) {
        let resultDescription = String(describing: result)
        DiagnosticsLog.shared.record(
            "insert-verification-final-failure",
            metadata: [
                "app": baseline.profile.bundleIdentifier,
                "result": resultDescription,
                "acceptedChars": String(acceptedText.count),
                "retryCount": String(baseline.retryCount)
            ].merging(insertionFailureRecoverabilityMetadata(baseline: baseline)) { current, _ in current }
        )
        RawAutocompleteTraceLog.shared.record(
            type: .insertionFailed,
            suggestionID: baseline.suggestionID ?? "",
            appBundleIdentifier: baseline.profile.bundleIdentifier,
            fieldIdentity: baseline.fieldIdentity.traceDescription,
            requestMode: baseline.requestMode?.rawValue ?? "",
            acceptedText: acceptedText,
            outcome: resultDescription,
            reason: "insert-verification-failed",
            metadata: [
                "acceptanceID": baseline.acceptanceID,
                "acceptMode": baseline.acceptMode,
                "fieldKind": baseline.fieldKind.rawValue,
                "fieldKindReason": baseline.fieldKindReason,
                "behaviorProfile": baseline.behaviorProfileID.rawValue,
                "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
                "currentBeforeChars": String(context.textBeforeCursor.count),
                "previousAfterChars": String(baseline.previousTextAfterCursor.count),
                "currentAfterChars": String(context.textAfterCursor.count)
            ].merging(insertionFailureRecoverabilityMetadata(baseline: baseline)) { current, _ in current }
        )
        recordPersonalCaptureSuggestionEpisodeInsertionFailed(
            baseline: baseline,
            outcome: resultDescription,
            reason: "insert-verification-failed"
        )
        recordAnnoyanceSignal(
            .wrongInsertion,
            context: annoyanceContext(
                appBundleIdentifier: baseline.profile.bundleIdentifier,
                fieldIdentity: baseline.fieldIdentity,
                requestMode: baseline.requestMode,
                fieldKind: baseline.fieldKind
            ),
            suggestionID: baseline.suggestionID ?? "",
            reason: "insert-verification-failed",
            metadata: [
                "acceptanceID": baseline.acceptanceID,
                "acceptMode": baseline.acceptMode,
                "insertionResult": resultDescription
            ]
        )
        if baseline.profile.suppressesAfterInsertionFailure {
            suppressField(
                baseline.fieldIdentity,
                profile: baseline.profile,
                reason: "insert-verification-failed"
            )
        }
        hideSuggestion(reason: "insert-verification-failed")
    }

    func handleInsertionVerificationSuccess(
        acceptedText: String,
        baseline: InsertionVerificationBaseline
    ) {
        if baseline.retryCount > 0 {
            DiagnosticsLog.shared.record(
                "insert-verification-recovered",
                metadata: [
                    "app": baseline.profile.bundleIdentifier,
                    "acceptedChars": String(acceptedText.count),
                    "retryCount": String(baseline.retryCount)
                ]
            )
        }
        RawAutocompleteTraceLog.shared.record(
            type: .insertionVerified,
            suggestionID: baseline.suggestionID ?? "",
            appBundleIdentifier: baseline.profile.bundleIdentifier,
            fieldIdentity: baseline.fieldIdentity.traceDescription,
            requestMode: baseline.requestMode?.rawValue ?? "",
            acceptedText: acceptedText,
            outcome: "verified",
            metadata: [
                "acceptanceID": baseline.acceptanceID,
                "acceptMode": baseline.acceptMode,
                "fieldKind": baseline.fieldKind.rawValue,
                "fieldKindReason": baseline.fieldKindReason,
                "behaviorProfile": baseline.behaviorProfileID.rawValue
            ]
        )
        recordPersonalCaptureSuggestionEpisodeAction(
            suggestionID: baseline.suggestionID ?? "",
            appBundleIdentifier: baseline.profile.bundleIdentifier,
            outcome: .accepted,
            reason: "insertion-verified",
            acceptedText: acceptedText,
            metadata: [
                "acceptanceID": baseline.acceptanceID,
                "acceptMode": baseline.acceptMode,
                "fieldKind": baseline.fieldKind.rawValue,
                "fieldKindReason": baseline.fieldKindReason,
                "behaviorProfile": baseline.behaviorProfileID.rawValue
            ]
        )
        recordPersonalCaptureAcceptedSuggestion(
            acceptedText: acceptedText,
            baseline: baseline
        )
        let tracker = AcceptanceSurvivalTracker(
            acceptanceID: baseline.acceptanceID,
            suggestionID: baseline.suggestionID ?? "",
            appBundleIdentifier: baseline.profile.bundleIdentifier,
            fieldIdentity: baseline.fieldIdentity,
            requestMode: baseline.requestMode?.rawValue ?? "",
            acceptMode: baseline.acceptMode,
            acceptedText: acceptedText,
            textBeforeCursorAtAccept: baseline.previousTextBeforeCursor,
            expectedInsertionUTF16Offset: baseline.previousTextBeforeCursor.utf16.count,
            acceptedAt: baseline.acceptedAt,
            profile: baseline.profile,
            fieldKind: baseline.fieldKind,
            fieldKindReason: baseline.fieldKindReason,
            behaviorProfileID: baseline.behaviorProfileID
        )
        startAcceptanceSurvivalTracking(tracker)
    }
}
