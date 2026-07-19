import Foundation
import AutocompleteLabCore

/// Owns the mutable live-suggestion snapshot used by native acceptance and presentation plumbing.
@MainActor
final class CurrentSuggestionStateHost {
    private var state = CurrentSuggestionState()

    var id: String? {
        get { state.id }
        set { state.id = newValue }
    }

    var appBundleIdentifier: String? {
        get { state.appBundleIdentifier }
        set { state.appBundleIdentifier = newValue }
    }

    var fieldIdentity: FocusedFieldIdentity? {
        get { state.fieldIdentity }
        set { state.fieldIdentity = newValue }
    }

    var requestMode: CompletionRequestMode? {
        get { state.requestMode }
        set { state.requestMode = newValue }
    }

    var textBeforeCursor: String? {
        get { state.textBeforeCursor }
        set { state.textBeforeCursor = newValue }
    }

    var acceptanceSnapshot: SuggestionAcceptanceSnapshot? {
        get { state.acceptanceSnapshot }
        set { state.acceptanceSnapshot = newValue }
    }

    var displayedText: String? {
        get { state.displayedText }
        set { state.displayedText = newValue }
    }

    var optimisticOriginalDisplayedText: String? {
        get { state.optimisticOriginalDisplayedText }
        set { state.optimisticOriginalDisplayedText = newValue }
    }

    var optimisticTypedPrefix: String {
        get { state.optimisticTypedPrefix }
        set { state.optimisticTypedPrefix = newValue }
    }

    var fieldClassification: AXFieldClassification? {
        get { state.fieldClassification }
        set { state.fieldClassification = newValue }
    }

    var presentedAt: Date? {
        get { state.presentedAt }
        set { state.presentedAt = newValue }
    }

    var displayScoreFinal: Double? {
        get { state.displayScoreFinal }
        set { state.displayScoreFinal = newValue }
    }

    var firstWordCorrectionGraceUsed: Bool {
        get { state.firstWordCorrectionGraceUsed }
        set { state.firstWordCorrectionGraceUsed = newValue }
    }

    var invalidatedByUserKeyDown: Bool {
        get { state.invalidatedByUserKeyDown }
        set { state.invalidatedByUserKeyDown = newValue }
    }

    @discardableResult
    func applyOptimisticTypeThrough(
        _ transition: KeyboardOptimisticTypeThroughTransition
    ) -> Bool {
        state.applyOptimisticTypeThrough(transition)
    }
}
