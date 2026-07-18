import Foundation
import AutocompleteLabCore

@MainActor
struct InsertionVerificationBaselineHostDependencies {
    let currentFieldIdentity: () -> FocusedFieldIdentity?
    let lastTextSnapshot: () -> FocusedTextSnapshot?
    let currentSuggestionState: CurrentSuggestionStateHost
    let currentProfile: () -> CompatibilityProfile?
    let currentBehaviorProfileID: () -> AutocompleteBehaviorProfileID?
}

/// Builds the immutable acceptance snapshot used by delayed insertion verification.
@MainActor
final class InsertionVerificationBaselineHost {
    private let dependencies: InsertionVerificationBaselineHostDependencies

    init(dependencies: InsertionVerificationBaselineHostDependencies) {
        self.dependencies = dependencies
    }

    func baseline(
        acceptanceID: String,
        acceptedAt: Date,
        action: KeyboardAction?,
        acceptMode: String
    ) -> InsertionVerificationBaseline? {
        guard let currentFieldIdentity = dependencies.currentFieldIdentity(),
              let lastTextSnapshot = dependencies.lastTextSnapshot(),
              lastTextSnapshot.fieldIdentity == currentFieldIdentity,
              let currentSuggestionAcceptanceSnapshot = dependencies.currentSuggestionState.acceptanceSnapshot,
              let profile = dependencies.currentProfile() else {
            return nil
        }

        let fieldClassification = dependencies.currentSuggestionState.fieldClassification
        let fieldKind = fieldClassification?.kind ?? .unknown
        let behaviorProfileID = dependencies.currentBehaviorProfileID()
            ?? AutocompleteBehaviorProfileResolver().profile(for: AutocompleteBehaviorProfileInput(
                appBundleIdentifier: profile.bundleIdentifier,
                fieldKind: fieldKind,
                currentLineStructure: CurrentLineStructure.from(textBeforeCursor: lastTextSnapshot.textBeforeCursor)
            )).id

        return InsertionVerificationBaseline(
            fieldIdentity: currentFieldIdentity,
            targetFingerprint: currentSuggestionAcceptanceSnapshot.targetFingerprint.postInsertionScope,
            previousTextBeforeCursor: lastTextSnapshot.textBeforeCursor,
            previousTextAfterCursor: lastTextSnapshot.textAfterCursor,
            profile: profile,
            suggestionID: dependencies.currentSuggestionState.id,
            requestMode: dependencies.currentSuggestionState.requestMode,
            acceptanceID: acceptanceID,
            acceptedAt: acceptedAt,
            action: action,
            acceptMode: acceptMode,
            fieldKind: fieldKind,
            fieldKindReason: fieldClassification?.reason ?? "unknown",
            behaviorProfileID: behaviorProfileID,
            retryCount: 0
        )
    }
}
