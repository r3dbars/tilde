import AutocompleteLabCore
import Foundation

struct VisibleSuggestionState: Equatable {
    private var session = SuggestionSession()
    private var metadata: VisibleSuggestionMetadata?

    private(set) var isInvalidatedByUserKeyDown = false

    var hasVisibleSuggestion: Bool {
        session.hasVisibleSuggestion
    }

    var visibleSuggestion: CompletionSuggestion? {
        session.visibleSuggestion
    }

    var suggestionID: String? {
        metadata?.suggestionID
    }

    var appBundleIdentifier: String? {
        metadata?.appBundleIdentifier
    }

    var fieldIdentity: FocusedFieldIdentity? {
        metadata?.fieldIdentity
    }

    var requestMode: CompletionRequestMode? {
        metadata?.requestMode
    }

    var textBeforeCursor: String? {
        metadata?.textBeforeCursor
    }

    var displayedText: String? {
        metadata?.displayedText
    }

    mutating func present(
        _ suggestion: CompletionSuggestion,
        suggestionID: String,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        requestMode: CompletionRequestMode,
        textBeforeCursor: String
    ) {
        session.present(suggestion)
        metadata = VisibleSuggestionMetadata(
            suggestionID: suggestionID,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity,
            requestMode: requestMode,
            textBeforeCursor: textBeforeCursor,
            displayedText: suggestion.visibleText
        )
        isInvalidatedByUserKeyDown = false
    }

    mutating func markInvalidatedByUserKeyDown() {
        isInvalidatedByUserKeyDown = true
    }

    mutating func nextWordAcceptance() -> String? {
        session.nextWordAcceptance()
    }

    mutating func allVisibleAcceptance() -> String? {
        session.allVisibleAcceptance()
    }

    mutating func commitNextWordAcceptance(_ acceptedText: String) {
        session.commitNextWordAcceptance(acceptedText)
    }

    mutating func commitAllVisibleAcceptance(_ acceptedText: String) {
        session.commitAllVisibleAcceptance(acceptedText)
    }

    mutating func updateDisplayedTextFromVisibleSuggestion() -> CompletionSuggestion? {
        guard let suggestion = session.visibleSuggestion else {
            return nil
        }

        metadata?.displayedText = suggestion.visibleText
        return suggestion
    }

    mutating func advanceBaseline(afterAccepting acceptedText: String, snapshotTextBeforeCursor: String?) {
        guard !acceptedText.isEmpty else {
            return
        }

        if let snapshotTextBeforeCursor {
            metadata?.textBeforeCursor = snapshotTextBeforeCursor
            return
        }

        if let textBeforeCursor {
            metadata?.textBeforeCursor = textBeforeCursor + acceptedText
        }
    }

    mutating func dismiss() {
        session.dismiss()
        metadata = nil
        isInvalidatedByUserKeyDown = false
    }
}

private struct VisibleSuggestionMetadata: Equatable {
    let suggestionID: String
    let appBundleIdentifier: String
    let fieldIdentity: FocusedFieldIdentity
    let requestMode: CompletionRequestMode
    var textBeforeCursor: String
    var displayedText: String
}
