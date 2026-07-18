import AppKit
import AutocompleteLabCore

/// Cohesive container for the live "current suggestion" state owned by
/// `AppDelegate`.
///
/// These fields together describe the suggestion that is currently presented
/// (or was most recently presented) to the user: its identity, the target app
/// and field it belongs to, the request that produced it, the text baseline it
/// was computed against, and presentation bookkeeping used by the acceptance,
/// visibility, and suppression stages.
///
/// The value also owns the atomic text-revision update needed when the user types
/// through a visible suggestion, keeping acceptance validation in sync.
struct CurrentSuggestionState {
    var id: String?
    var appBundleIdentifier: String?
    var fieldIdentity: FocusedFieldIdentity?
    var requestMode: CompletionRequestMode?
    var textBeforeCursor: String?
    var acceptanceSnapshot: SuggestionAcceptanceSnapshot?
    var displayedText: String?
    var optimisticOriginalDisplayedText: String?
    var optimisticTypedPrefix = ""
    var fieldClassification: AXFieldClassification?
    var presentedAt: Date?
    var displayScoreFinal: Double?
    var invalidatedByUserKeyDown = false

    mutating func applyOptimisticTypeThrough(
        _ transition: KeyboardOptimisticTypeThroughTransition
    ) -> Bool {
        guard let originalTextBeforeCursor = textBeforeCursor else {
            return false
        }

        if optimisticOriginalDisplayedText == nil {
            optimisticOriginalDisplayedText = displayedText
        }
        optimisticTypedPrefix = transition.typedPrefix
        switch transition {
        case let .matched(typedCharacter, _, _):
            textBeforeCursor = originalTextBeforeCursor + String(typedCharacter)
        case .retreated:
            textBeforeCursor = String(originalTextBeforeCursor.dropLast())
        }

        if let acceptanceSnapshot, let textBeforeCursor {
            self.acceptanceSnapshot = acceptanceSnapshot.advancingTextRevision(
                textBeforeCursor: textBeforeCursor,
                textAfterCursor: acceptanceSnapshot.textAfterCursor,
                selectedTextLength: acceptanceSnapshot.selectedTextLength
            )
        }
        return true
    }
}

func suggestionHiddenOutcome(for reason: String) -> String {
    if reason.hasPrefix("accepted") {
        return "accepted"
    }
    if reason == "typed-through-visible-prefix"
        || reason.hasPrefix("type-through-")
        || reason == "optimistic-type-through-mismatch" {
        return "typed-through"
    }
    if reason == "typed-over" {
        return "typed-over"
    }
    return "ignored"
}
